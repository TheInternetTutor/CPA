#!/usr/bin/env bash
set -euo pipefail

INPUT=${1:?usage: fifo_lots.sh NORMALIZED.jsonl MATCHES.jsonl OPEN_LOTS.jsonl}
MATCHES=${2:?usage: fifo_lots.sh NORMALIZED.jsonl MATCHES.jsonl OPEN_LOTS.jsonl}
OPEN=${3:?usage: fifo_lots.sh NORMALIZED.jsonl MATCHES.jsonl OPEN_LOTS.jsonl [WARNINGS.log]}
WARNINGS=${4:-${OPEN%.jsonl}.warnings.log}

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

jq -sr --slurpfile actions corporate_actions.json '
  def adjusted_trade($r):
    reduce $actions[0][] as $a ($r;
      if .asset_type == $a.symbol and .date < ($a.effective_date + " 00:00:00") then
        .asset_amount_value = (.asset_amount_value * $a.ratio)
        | .execution_price = (.execution_price / $a.ratio)
      else . end);
  map(select(.analysis_class == "STOCK_BUY_COMPLETED" or .analysis_class == "STOCK_SELL_COMPLETED"))
  | map(adjusted_trade(.))
  | sort_by(.date, .source_row)
  | .[]
  | [(.source_row|tostring), .date, .asset_type, .trading_side, (.asset_amount_value|tostring), (.execution_price|tostring), (.amount_value|tostring)]
  | @tsv
' "$INPUT" > "$TMP"

: > "$MATCHES"
: > "$OPEN"
: > "$WARNINGS"

awk -F '\t' -v MATCHES="$MATCHES" -v OPEN="$OPEN" -v WARNINGS="$WARNINGS" '
function esc(s,    t) {
    t=s
    gsub(/\\/, "\\\\", t)
    gsub(/"/, "\\\"", t)
    gsub(/\r/, "\\r", t)
    gsub(/\n/, "\\n", t)
    return t
}
function emit_match(symbol,buy_row,buy_date,buy_qty,buy_price,sell_row,sell_date,sell_qty,sell_price,    cost,proceeds,pnl) {
    cost = buy_qty * buy_price
    proceeds = sell_qty * sell_price
    pnl = proceeds - cost
    printf "{\"symbol\":\"%s\",\"buy_source_row\":%d,\"buy_date\":\"%s\",\"sell_source_row\":%d,\"sell_date\":\"%s\",\"quantity\":%.10f,\"buy_price\":%.10f,\"sell_price\":%.10f,\"cost\":%.10f,\"proceeds\":%.10f,\"realized_pnl\":%.10f}\n", \
        esc(symbol), buy_row, esc(buy_date), sell_row, esc(sell_date), sell_qty, buy_price, sell_price, cost, proceeds, pnl >> MATCHES
}
{
    row=$1; date=$2; symbol=$3; side=$4; qty=$5+0; price=$6+0
    if (qty <= 0) {
        printf "error: non-positive quantity at source row %s\n", row > "/dev/stderr"
        exit 2
    }
    if (side == "BUY") {
        tail[symbol]++
        k=symbol SUBSEP tail[symbol]
        lot_qty[k]=qty
        lot_price[k]=price
        lot_date[k]=date
        lot_row[k]=row+0
    } else if (side == "SELL") {
        remaining=qty
        while (remaining > 0.001) {
            if (head[symbol] == 0) head[symbol]=1
            if (head[symbol] > tail[symbol]) {
                printf "error: unmatched sell quantity %.10f for %s at source row %s\n", remaining, symbol, row > "/dev/stderr"
                exit 3
            }
            k=symbol SUBSEP head[symbol]
            available=lot_qty[k]
            matched=(remaining < available ? remaining : available)
            emit_match(symbol, lot_row[k], lot_date[k], matched, lot_price[k], row+0, date, matched, price)
            lot_qty[k] -= matched
            remaining -= matched
            if (lot_qty[k] <= 0.0000000001) {
                delete lot_qty[k]
                delete lot_price[k]
                delete lot_date[k]
                delete lot_row[k]
                head[symbol]++
            }
        }
        if (remaining > 0 && remaining <= 0.001) {
            printf "%.10f\t%s\t%s\n", remaining, symbol, row >> WARNINGS
        }
    }
}
END {
    for (symbol in tail) {
        h=(head[symbol] ? head[symbol] : 1)
        for (i=h; i<=tail[symbol]; i++) {
            k=symbol SUBSEP i
            if (lot_qty[k] > 0.0000000001) {
                printf "{\"symbol\":\"%s\",\"buy_source_row\":%d,\"buy_date\":\"%s\",\"quantity\":%.10f,\"buy_price\":%.10f,\"cost\":%.10f}\n", \
                    esc(symbol), lot_row[k], esc(lot_date[k]), lot_qty[k], lot_price[k], lot_qty[k]*lot_price[k] >> OPEN
            }
        }
    }
}
' "$TMP"

jq -e . "$MATCHES" >/dev/null
jq -e . "$OPEN" >/dev/null
printf 'Wrote %s\n' "$MATCHES"
printf 'Wrote %s\n' "$OPEN"
