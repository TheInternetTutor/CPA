#!/usr/bin/env bash
set -euo pipefail

INPUT_MATCHES=${1:?usage: trade_efficiency.sh MATCHES.jsonl OUTPUT_DIR}
OUTPUT_DIR=${2:-.}

command -v jq >/dev/null || { echo 'error: jq is required' >&2; return 1 2>/dev/null || exit 1; }
command -v awk >/dev/null || { echo 'error: awk is required' >&2; return 1 2>/dev/null || exit 1; }
command -v date >/dev/null || { echo 'error: date is required' >&2; return 1 2>/dev/null || exit 1; }
mkdir -p "$OUTPUT_DIR"

OUTPUT="$OUTPUT_DIR/trade_efficiency.json"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Each FIFO fragment is evaluated independently. This avoids mixing winners
# and losers and preserves the actual FIFO holding period.
jq -r '[.symbol,.buy_date[0:10],.sell_date[0:10],.quantity,.cost,.proceeds,.realized_pnl] | @tsv' "$INPUT_MATCHES" |
awk -F '\t' -v OFS='\t' '
function epoch(d,    cmd,x){cmd="date -d \"" d "\" +%s"; cmd|getline x; close(cmd); return x}
{
  s=$1; bd=$2; sd=$3; q=$4+0; c=$5+0; pr=$6+0; p=$7+0
  days=(epoch(sd)-epoch(bd))/86400
  if(days<0) days=0
  ret=(c!=0 ? p/c : 0)
  profit_per_100=(c!=0 ? p/c*100 : 0)
  capital_days=c*days
  pnl_per_capital_day=(capital_days!=0 ? p/capital_days : 0)
  annualized_simple=(days>0 && c!=0 ? (p/c)*(365/days) : 0)
  printf "%s\t%s\t%s\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\n",s,bd,sd,q,c,pr,p,days,ret,capital_days,pnl_per_capital_day,annualized_simple
}' > "$TMP/fragments.tsv"

awk -F '\t' '
{
  n++; p=$7+0; c=$5+0; days=$8+0; ret=$9+0; cd=$10+0
  pnl+=p; cost+=c; proceeds+=$6
  hold+=days; capital_days+=cd
  if(p>0){win_count++; win_pnl+=p; win_cost+=c; win_hold+=days}
  else if(p<0){loss_count++; loss_pnl+=p; loss_cost+=c; loss_hold+=days}
  if(days>0){positive_days++}
  returns[n]=ret; holds[n]=days
  if(p>0){win_holds[++wn]=days} else if(p<0){loss_holds[++ln]=days}
}
END {
  # sort fragment returns for median and percentile diagnostics
  for(i=1;i<=n;i++) sr[i]=returns[i]
  for(i=2;i<=n;i++){v=sr[i];j=i-1;while(j>=1&&sr[j]>v){sr[j+1]=sr[j];j--}sr[j+1]=v}
  if(n==0) median=0; else if(n%2) median=sr[(n+1)/2]; else median=(sr[n/2]+sr[n/2+1])/2
  weighted=(cost!=0?pnl/cost:0)
  capital_eff=(capital_days!=0?pnl/capital_days:0)
  win_avg=(win_count ? win_hold/win_count : 0)
  loss_avg=(loss_count ? loss_hold/loss_count : 0)
  for(i=2;i<=wn;i++){v=win_holds[i];j=i-1;while(j>=1&&win_holds[j]>v){win_holds[j+1]=win_holds[j];j--}win_holds[j+1]=v}
  for(i=2;i<=ln;i++){v=loss_holds[i];j=i-1;while(j>=1&&loss_holds[j]>v){loss_holds[j+1]=loss_holds[j];j--}loss_holds[j+1]=v}
  if(n==0) median_hold=0; else if(n%2) median_hold=holds[(n+1)/2]; else {for(i=2;i<=n;i++){v=holds[i];j=i-1;while(j>=1&&holds[j]>v){holds[j+1]=holds[j];j--}holds[j+1]=v}; median_hold=(holds[n/2]+holds[n/2+1])/2}
  printf "%.10f\t%.10f\t%.10f\t%d\t%d\t%d\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\n",pnl,cost,proceeds,n,win_count,loss_count,weighted,median,hold/n,capital_days,capital_eff,win_cost,loss_cost,positive_days,win_avg,loss_avg,median_hold
}' "$TMP/fragments.tsv" > "$TMP/overall.tsv"

# Convert the fragment diagnostics to a compact JSONL file for downstream use.
awk -F '\t' '{a=($8>0?$9*(365/$8):0); printf "{\"symbol\":\"%s\",\"buy_date\":\"%s\",\"sell_date\":\"%s\",\"quantity\":%.10f,\"cost\":%.10f,\"proceeds\":%.10f,\"realized_pnl\":%.10f,\"holding_days\":%.10f,\"return_on_cost\":%.10f,\"capital_days\":%.10f,\"pnl_per_capital_day\":%.10f,\"simple_annualized_return\":%.10f}\n",$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,a}' "$TMP/fragments.tsv" > "$OUTPUT_DIR/trade_efficiency_fragments.jsonl"

# Symbol-level efficiency aggregation.
jq -r '[.symbol,.cost,.proceeds,.realized_pnl] | @tsv' "$INPUT_MATCHES" |
awk -F '\t' '
{sym=$1; cost[sym]+=$2+0; proceeds[sym]+=$3+0; pnl[sym]+=$4+0; n[sym]++}
END {for(s in pnl) printf "%s\t%.10f\t%.10f\t%.10f\t%d\n",s,cost[s],proceeds[s],pnl[s],n[s]}' |
sort -t $'\t' -k4,4nr > "$TMP/symbol_eff.tsv"

{ printf '['; first=1; while IFS=$'\t' read -r s c pr p n; do esc=$(printf '%s' "$s" | jq -Rsa .); (( first )) || printf ','; first=0; ret=$(awk -v p="$p" -v c="$c" 'BEGIN{if(c)printf "%.10f",p/c;else print 0}'); printf '{"symbol":%s,"matched_cost":%.10f,"matched_proceeds":%.10f,"realized_pnl":%.10f,"fifo_fragments":%d,"return_on_cost":%.10f}' "$esc" "$c" "$pr" "$p" "$n" "$ret"; done < "$TMP/symbol_eff.tsv"; printf ']\n'; } > "$TMP/symbol_eff.json"

read -r PNL COST PROCEEDS N W L ROC MEDIAN_RET AVG_HOLD CAPITAL_DAYS PNL_PER_CAPITAL_DAY WIN_COST LOSS_COST POSITIVE_DAYS WIN_AVG_HOLD LOSS_AVG_HOLD MEDIAN_HOLD < "$TMP/overall.tsv"
TURNOVER=$(awk -v p="$PROCEEDS" -v c="$COST" 'BEGIN{if(c)printf "%.10f",p/c;else print "null"}')
AVG_PNL=$(awk -v p="$PNL" -v n="$N" 'BEGIN{if(n)printf "%.10f",p/n;else print "null"}')
WIN_RETURN=$(awk -v p="$PNL" -v wc="$WIN_COST" 'BEGIN{# use gross winner dollars via separate jq below; placeholder replaced
print "0"}')

GROSS_PROFIT=$(jq -s '[.[]|select(.realized_pnl>0)|.realized_pnl]|add // 0' "$INPUT_MATCHES")
GROSS_LOSS=$(jq -s '[.[]|select(.realized_pnl<0)|.realized_pnl]|add // 0' "$INPUT_MATCHES")
AVG_WIN=$(awk -v gp="$GROSS_PROFIT" -v w="$W" 'BEGIN{if(w)printf "%.10f",gp/w;else print "null"}')
AVG_LOSS=$(awk -v gl="$GROSS_LOSS" -v l="$L" 'BEGIN{if(l)printf "%.10f",gl/l;else print "null"}')
WIN_COST_RETURN=$(awk -v gp="$GROSS_PROFIT" -v c="$WIN_COST" 'BEGIN{if(c)printf "%.10f",gp/c;else print "null"}')
LOSS_COST_RETURN=$(awk -v gl="$GROSS_LOSS" -v c="$LOSS_COST" 'BEGIN{if(c)printf "%.10f",gl/c;else print "null"}')

jq -n \
  --argjson realized_pnl "$PNL" \
  --argjson matched_cost "$COST" \
  --argjson matched_proceeds "$PROCEEDS" \
  --argjson fifo_fragments "$N" \
  --argjson winning_fragments "$W" \
  --argjson losing_fragments "$L" \
  --argjson return_on_matched_cost "$ROC" \
  --argjson turnover "$TURNOVER" \
  --argjson average_fragment_pnl "$AVG_PNL" \
  --argjson median_fragment_return_on_cost "$MEDIAN_RET" \
  --argjson average_holding_days "$AVG_HOLD" \
  --argjson winning_average_holding_days "$WIN_AVG_HOLD" \
  --argjson losing_average_holding_days "$LOSS_AVG_HOLD" \
  --argjson median_holding_days "$MEDIAN_HOLD" \
  --argjson capital_days "$CAPITAL_DAYS" \
  --argjson pnl_per_capital_day "$PNL_PER_CAPITAL_DAY" \
  --argjson gross_profit "$GROSS_PROFIT" \
  --argjson gross_loss "$GROSS_LOSS" \
  --argjson average_win "$AVG_WIN" \
  --argjson average_loss "$AVG_LOSS" \
  --argjson winner_return_on_cost "$WIN_COST_RETURN" \
  --argjson loser_return_on_cost "$LOSS_COST_RETURN" \
  --slurpfile symbols "$TMP/symbol_eff.json" \
  '{analysis_scope:"realized FIFO fragments",efficiency:{realized_pnl:$realized_pnl,matched_cost:$matched_cost,matched_proceeds:$matched_proceeds,return_on_matched_cost:$return_on_matched_cost,turnover_proceeds_to_cost:$turnover,average_fragment_pnl:$average_fragment_pnl,median_fragment_return_on_cost:$median_fragment_return_on_cost,average_holding_days:$average_holding_days,winning_average_holding_days:$winning_average_holding_days,losing_average_holding_days:$losing_average_holding_days,median_holding_days:$median_holding_days,capital_days:$capital_days,pnl_per_capital_day:$pnl_per_capital_day},win_loss_efficiency:{gross_profit:$gross_profit,gross_loss:$gross_loss,average_win:$average_win,average_loss:$average_loss,winner_return_on_cost:$winner_return_on_cost,loser_return_on_cost:$loser_return_on_cost},by_symbol:$symbols[0],methodology:{capital_days:"sum of FIFO fragment cost multiplied by holding days",pnl_per_capital_day:"realized P&L divided by capital-days; descriptive efficiency measure, not a standard annualized return",turnover:"matched proceeds divided by matched FIFO cost",simple_annualized_return:"not included in summary because short holding periods can make annualization misleading"}}' > "$OUTPUT"

jq -e . "$OUTPUT" >/dev/null
jq -e . "$OUTPUT_DIR/trade_efficiency_fragments.jsonl" >/dev/null
printf 'Wrote %s\nWrote %s\n' "$OUTPUT" "$OUTPUT_DIR/trade_efficiency_fragments.jsonl"
