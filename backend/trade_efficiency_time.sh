#!/usr/bin/env bash
set -euo pipefail

INPUT=${1:?usage: trade_efficiency_time.sh TRADE_EFFICIENCY_FRAGMENTS.jsonl OUTPUT_DIR}
OUTPUT_DIR=${2:-.}

command -v jq >/dev/null || { echo 'error: jq is required' >&2; return 1 2>/dev/null || exit 1; }
mkdir -p "$OUTPUT_DIR"

MONTHLY="$OUTPUT_DIR/trade_efficiency_monthly.jsonl"
YEARLY="$OUTPUT_DIR/trade_efficiency_yearly.jsonl"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Efficiency is attributed to the period in which the FIFO fragment was realized.
# This preserves the realized-P&L convention used by the rest of the engine.
jq -r '[.sell_date[0:7],.sell_date[0:4],.cost,.proceeds,.realized_pnl,.holding_days,.capital_days] | @tsv' "$INPUT" > "$TMP/rows.tsv"

aggregate() {
  local group_index="$1"
  local output="$2"

  awk -F '\t' -v GI="$group_index" '
  {
    key=$GI
    cost[key]+=$3+0
    proceeds[key]+=$4+0
    pnl[key]+=$5+0
    hold[key]+=$6+0
    capital_days[key]+=$7+0
    fragments[key]++
    if(($5+0)>0){wins[key]++; gross_profit[key]+=$5+0}
    else if(($5+0)<0){losses[key]++; gross_loss[key]+=$5+0}
  }
  END {
    for(key in fragments){
      c=cost[key]; pr=proceeds[key]; p=pnl[key]; n=fragments[key]
      roc=(c!=0?p/c:0)
      turnover=(c!=0?pr/c:0)
      avg_pnl=(n!=0?p/n:0)
      avg_hold=(n!=0?hold[key]/n:0)
      cap_eff=(capital_days[key]!=0?p/capital_days[key]:0)
      win_rate=(n!=0?wins[key]/n:0)
      if(gross_loss[key]<0) pf=sprintf("%.10f",gross_profit[key]/(-gross_loss[key])); else pf="null"
      printf "%s\t%.10f\t%.10f\t%.10f\t%d\t%d\t%d\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%s\n",key,c,pr,p,n,wins[key]+0,losses[key]+0,roc,turnover,avg_pnl,avg_hold,capital_days[key],cap_eff,win_rate,pf
    }
  }' "$TMP/rows.tsv" | sort -t $'\t' -k1,1 > "$TMP/agg.tsv"

  {
    while IFS=$'\t' read -r period cost proceeds pnl fragments wins losses roc turnover avg_pnl avg_hold capital_days cap_eff win_rate profit_factor; do
      jq -nc \
        --arg period "$period" \
        --argjson matched_cost "$cost" \
        --argjson matched_proceeds "$proceeds" \
        --argjson realized_pnl "$pnl" \
        --argjson fifo_fragments "$fragments" \
        --argjson winning_fragments "$wins" \
        --argjson losing_fragments "$losses" \
        --argjson return_on_matched_cost "$roc" \
        --argjson turnover_proceeds_to_cost "$turnover" \
        --argjson average_fragment_pnl "$avg_pnl" \
        --argjson average_holding_days "$avg_hold" \
        --argjson capital_days "$capital_days" \
        --argjson pnl_per_capital_day "$cap_eff" \
        --argjson win_rate "$win_rate" \
        --argjson profit_factor "$profit_factor" \
        '{period:$period,matched_cost:$matched_cost,matched_proceeds:$matched_proceeds,realized_pnl:$realized_pnl,fifo_fragments:$fifo_fragments,winning_fragments:$winning_fragments,losing_fragments:$losing_fragments,return_on_matched_cost:$return_on_matched_cost,turnover_proceeds_to_cost:$turnover_proceeds_to_cost,average_fragment_pnl:$average_fragment_pnl,average_holding_days:$average_holding_days,capital_days:$capital_days,pnl_per_capital_day:$pnl_per_capital_day,win_rate:$win_rate,profit_factor:$profit_factor}'
    done < "$TMP/agg.tsv"
  } > "$output"
}

aggregate 1 "$MONTHLY"
aggregate 2 "$YEARLY"

jq -e . "$MONTHLY" >/dev/null
jq -e . "$YEARLY" >/dev/null
printf 'Wrote %s\nWrote %s\n' "$MONTHLY" "$YEARLY"
