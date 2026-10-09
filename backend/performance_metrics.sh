#!/usr/bin/env bash
set -euo pipefail

INPUT_NORMALIZED=${1:?usage: performance_metrics.sh NORMALIZED.jsonl MATCHES.jsonl OUTPUT_DIR}
INPUT_MATCHES=${2:?usage: performance_metrics.sh NORMALIZED.jsonl MATCHES.jsonl OUTPUT_DIR}
OUTPUT_DIR=${3:-.}

command -v jq >/dev/null || { echo 'error: jq is required' >&2; exit 1; }
command -v awk >/dev/null || { echo 'error: awk is required' >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"

DAILY="$OUTPUT_DIR/daily_performance.jsonl"
ROLLING="$OUTPUT_DIR/rolling_performance.jsonl"
SYMBOLS="$OUTPUT_DIR/symbol_attribution.json"
SUMMARY="$OUTPUT_DIR/performance_summary.json"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Matched FIFO fragments aggregated by sell date.
jq -r '[.sell_date[0:10], .realized_pnl, .cost, .proceeds] | @tsv' "$INPUT_MATCHES" |
awk -F '\t' '
{
  d=$1; p=$2+0; c=$3+0; pr=$4+0
  pnl_sum[d]+=p; cost_sum[d]+=c; proceeds_sum[d]+=pr
  fragments[d]++
  if (p > 0) wins[d]++; else if (p < 0) losses[d]++; else flat[d]++
}
END {
  for (d in pnl_sum) printf "%s\t%.10f\t%.10f\t%.10f\t%d\t%d\t%d\n", d,pnl_sum[d],cost_sum[d],proceeds_sum[d],fragments[d],wins[d]+0,losses[d]+0
}' | sort > "$TMP/daily.tsv"

# Build complete calendar range from first to last realized day. Missing days are explicit zeros.
FIRST=$(head -1 "$TMP/daily.tsv" | cut -f1)
LAST=$(tail -1 "$TMP/daily.tsv" | cut -f1)
: > "$TMP/calendar.tsv"
if [[ -n "$FIRST" ]]; then
  d="$FIRST"
  while [[ "$d" < "$LAST" || "$d" == "$LAST" ]]; do
    row=$(awk -F '\t' -v d="$d" '$1==d {print; found=1} END {if(!found) print d "\t0\t0\t0\t0\t0\t0"}' "$TMP/daily.tsv")
    printf '%s\n' "$row" >> "$TMP/calendar.tsv"
    d=$(date -I -d "$d + 1 day")
  done
fi

awk -F '\t' -v OFS='\t' '
{
  date[NR]=$1; pnl[NR]=$2+0; cost[NR]=$3+0; proceeds[NR]=$4+0; fragments[NR]=$5+0; wins[NR]=$6+0; losses[NR]=$7+0
  cum+=pnl[NR]
  cumulative[NR]=cum
  if (NR==1 || cum>peak) peak=cum
  dd=cum-peak
  drawdown[NR]=dd
  if (NR==1 || dd<maxdd) maxdd=dd
}
END {
  for(i=1;i<=NR;i++) printf "%s\t%.10f\t%.10f\t%.10f\t%d\t%d\t%d\t%.10f\t%.10f\n",date[i],pnl[i],cost[i],proceeds[i],fragments[i],wins[i],losses[i],cumulative[i],drawdown[i]
}' "$TMP/calendar.tsv" > "$TMP/daily_enriched.tsv"

awk -F '\t' -v OFS='\t' '
function sum_back(n,    j,s) { s=0; for(j=i;j>=1 && j>i-n;j--) s+=pnl[j]; return s }
{
  date[++i]=$1; pnl[i]=$2+0
}
END {
  for(j=1;j<=i;j++) printf "%s\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\n",date[j],sum_back(7),sum_back(30),sum_back(60),sum_back(120),sum_back(365)
}' "$TMP/daily_enriched.tsv" > "$TMP/rolling.tsv"

# External cash flows. Positive values are external inflows; negative values are external outflows.
jq -r 'select(.external_cash_flow != 0) | [.date[0:10], .analysis_class, .external_cash_flow] | @tsv' "$INPUT_NORMALIZED" > "$TMP/external.tsv"

awk -F '\t' '
{
  flow=$3+0; total+=flow
  if(flow>0){inflow+=flow; inflow_count++} else if(flow<0){outflow+=flow; outflow_count++}
  class[$2]+=flow; class_count[$2]++
}
END {
  printf "%.10f\t%.10f\t%.10f\t%d\t%d\n",inflow,outflow,total,inflow_count,outflow_count > "'"$TMP"'/external_totals.tsv"
  for(c in class) printf "%s\t%.10f\t%d\n",c,class[c],class_count[c] > "'"$TMP"'/external_classes.tsv"
}' "$TMP/external.tsv"

# Symbol attribution and fragment-level trading statistics.
jq -r '[.symbol, .realized_pnl, .cost, .proceeds, .quantity] | @tsv' "$INPUT_MATCHES" |
awk -F '\t' '
{
  s=$1; p=$2+0; c=$3+0; pr=$4+0; q=$5+0
  pnl[s]+=p; cost[s]+=c; proceeds[s]+=pr; qty[s]+=q; fragments[s]++
  if(p>0){wins[s]+=p; win_count[s]++} else if(p<0){losses[s]+=p; loss_count[s]++}
}
END {
  for(s in pnl) printf "%s\t%.10f\t%.10f\t%.10f\t%.10f\t%d\t%d\t%d\n",s,pnl[s],cost[s],proceeds[s],qty[s],fragments[s],win_count[s]+0,loss_count[s]+0
}' | sort -t $'\t' -k2,2nr > "$TMP/symbols.tsv"

# Daily JSONL.
awk -F '\t' '{printf "{\"date\":\"%s\",\"realized_pnl\":%.10f,\"matched_cost\":%.10f,\"proceeds\":%.10f,\"fifo_fragments\":%d,\"wins\":%d,\"losses\":%d,\"cumulative_realized_pnl\":%.10f,\"drawdown\":%.10f}\n",$1,$2,$3,$4,$5,$6,$7,$8,$9}' "$TMP/daily_enriched.tsv" > "$DAILY"

# Rolling JSONL.
awk -F '\t' '{printf "{\"date\":\"%s\",\"pnl_7d\":%.10f,\"pnl_30d\":%.10f,\"pnl_60d\":%.10f,\"pnl_120d\":%.10f,\"pnl_1y\":%.10f}\n",$1,$2,$3,$4,$5,$6}' "$TMP/rolling.tsv" > "$ROLLING"

# Symbol JSON array.
{
  printf '['
  first=1
  while IFS=$'\t' read -r s p c pr q f w l; do
    [[ -n "$s" ]] || continue
    esc=$(printf '%s' "$s" | jq -Rsa .)
    (( first )) || printf ','
    first=0
    printf '{"symbol":%s,"realized_pnl":%.10f,"matched_cost":%.10f,"proceeds":%.10f,"matched_quantity":%.10f,"fifo_fragments":%d,"wins":%d,"losses":%d}' "$esc" "$p" "$c" "$pr" "$q" "$f" "$w" "$l"
  done < "$TMP/symbols.tsv"
  printf ']\n'
} > "$SYMBOLS"

# Overall trading statistics. Gross gain/loss and averages are computed
# directly from FIFO fragments, not from netted daily P&L.
jq -r '[.realized_pnl, .cost, .proceeds] | @tsv' "$INPUT_MATCHES" |
awk -F '\t' '
{
 p=$1+0; cost+=$2; proceeds+=$3; fragments++
 if(p>0){gross_profit+=p; wins++} else if(p<0){gross_loss+=p; losses++}
}
END {printf "%.10f\t%.10f\t%.10f\t%d\t%d\t%d\t%.10f\t%.10f\n",cost,proceeds,proceeds-cost,fragments,wins,losses,gross_profit,gross_loss}' > "$TMP/overall_trades.tsv"

awk -F '\t' '
BEGIN {maxdd=0}
{dd=$9+0; if(dd<maxdd) maxdd=dd}
END {printf "%.10f\n",maxdd}' "$TMP/daily_enriched.tsv" > "$TMP/maxdd.tsv"

read -r MATCHED_COST MATCHED_PROCEEDS REALIZED_PNL FRAGMENTS WINS LOSSES GROSS_PROFIT GROSS_LOSS < "$TMP/overall_trades.tsv"
MAX_DD=$(cat "$TMP/maxdd.tsv")
read -r EXTERNAL_IN EXTERNAL_OUT EXTERNAL_NET EXTERNAL_IN_COUNT EXTERNAL_OUT_COUNT < "$TMP/external_totals.tsv"

PROFIT_FACTOR=$(awk -v gp="$GROSS_PROFIT" -v gl="$GROSS_LOSS" 'BEGIN{if(gl<0) printf "%.10f",gp/(-gl); else if(gp>0) printf "null"; else printf "0"}')
WIN_RATE=$(awk -v w="$WINS" -v l="$LOSSES" 'BEGIN{n=w+l;if(n) printf "%.10f",w/n; else printf "null"}')
AVG_WIN=$(awk -v gp="$GROSS_PROFIT" -v w="$WINS" 'BEGIN{if(w) printf "%.10f",gp/w; else printf "null"}')
AVG_LOSS=$(awk -v gl="$GROSS_LOSS" -v l="$LOSSES" 'BEGIN{if(l) printf "%.10f",gl/l; else printf "null"}')
RETURN_COST=$(awk -v p="$REALIZED_PNL" -v c="$MATCHED_COST" 'BEGIN{if(c) printf "%.10f",p/c; else printf "null"}')

jq -n \
  --arg first "$FIRST" --arg last "$LAST" \
  --argjson matched_cost "$MATCHED_COST" \
  --argjson matched_proceeds "$MATCHED_PROCEEDS" \
  --argjson realized_pnl "$REALIZED_PNL" \
  --argjson fifo_fragments "$FRAGMENTS" \
  --argjson wins "$WINS" --argjson losses "$LOSSES" \
  --argjson gross_profit "$GROSS_PROFIT" --argjson gross_loss "$GROSS_LOSS" \
  --argjson max_drawdown "$MAX_DD" --argjson profit_factor "$PROFIT_FACTOR" \
  --argjson win_rate "$WIN_RATE" --argjson avg_win "$AVG_WIN" --argjson avg_loss "$AVG_LOSS" \
  --argjson return_on_matched_cost "$RETURN_COST" \
  --argjson external_inflows "$EXTERNAL_IN" --argjson external_outflows "$EXTERNAL_OUT" --argjson net_external_capital "$EXTERNAL_NET" \
  --argjson external_inflow_count "$EXTERNAL_IN_COUNT" --argjson external_outflow_count "$EXTERNAL_OUT_COUNT" \
  '{analysis_period:{first_realized_day:$first,last_realized_day:$last},trading:{matched_cost:$matched_cost,matched_proceeds:$matched_proceeds,realized_pnl:$realized_pnl,return_on_matched_cost:$return_on_matched_cost,fifo_fragments:$fifo_fragments,wins:$wins,losses:$losses,win_rate:$win_rate,gross_profit:$gross_profit,gross_loss:$gross_loss,profit_factor:$profit_factor,average_win:$avg_win,average_loss:$avg_loss,max_realized_drawdown:$max_drawdown},external_capital:{gross_inflows:$external_inflows,gross_outflows:$external_outflows,net_external_capital:$net_external_capital,inflow_count:$external_inflow_count,outflow_count:$external_outflow_count},rolling_windows_days:[7,30,60,120,365],notes:["Trading P&L is based on FIFO-matched stock sale fragments.","Dividends and interest are excluded from trading P&L.","External capital includes normalized external cash movements; internal savings transfers are excluded.","Open-position market value is not included because historical mark prices are unavailable in the source CSV."]}' > "$SUMMARY"

jq -e . "$SYMBOLS" >/dev/null
jq -e . "$SUMMARY" >/dev/null
jq -e . "$DAILY" >/dev/null
jq -e . "$ROLLING" >/dev/null
printf 'Wrote %s\nWrote %s\nWrote %s\nWrote %s\n' "$SUMMARY" "$DAILY" "$ROLLING" "$SYMBOLS"
