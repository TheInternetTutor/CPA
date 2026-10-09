#!/usr/bin/env bash
set -euo pipefail

INPUT_MATCHES=${1:?usage: capital_velocity.sh MATCHES.jsonl EXTERNAL_CAPITAL.jsonl OUTPUT_DIR}
INPUT_CAPITAL=${2:?usage: capital_velocity.sh MATCHES.jsonl EXTERNAL_CAPITAL.jsonl OUTPUT_DIR}
OUTPUT_DIR=${3:-.}

command -v jq >/dev/null || { echo 'error: jq is required' >&2; return 1 2>/dev/null || exit 1; }
command -v awk >/dev/null || { echo 'error: awk is required' >&2; return 1 2>/dev/null || exit 1; }
mkdir -p "$OUTPUT_DIR"

SUMMARY="$OUTPUT_DIR/capital_velocity.json"
YEARLY="$OUTPUT_DIR/capital_velocity_yearly.jsonl"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Trading deployment is measured from realized FIFO fragments only.
# External capital is the actual cash-flow ledger; internal savings transfers
# are already excluded upstream.
jq -r '[.sell_date[0:10],.realized_pnl,.cost,.proceeds] | @tsv' "$INPUT_MATCHES" |
awk -F '\t' '
{
 d=$1; p=$2+0; c=$3+0; pr=$4+0; y=substr(d,1,4)
 pnl+=p; cost+=c; proceeds+=pr; fragments++
 days[d]=1; ycost[y]+=c; yproceeds[y]+=pr; ypnl[y]+=p; yfrags[y]++
 ydays[y,d]=1
}
END {
 for(d in days) active_days++
 for(k in ydays){ split(k,a,SUBSEP); yactive[a[1]]++ }
 printf "%.10f\t%.10f\t%.10f\t%d\t%d\n",pnl,cost,proceeds,fragments,active_days > "'"$TMP"'/overall.tsv"
 for(y in ycost) printf "%s\t%.10f\t%.10f\t%.10f\t%d\t%d\n",y,ypnl[y],ycost[y],yproceeds[y],yfrags[y],yactive[y] > "'"$TMP"'/trading_years.tsv"
}'

# External capital by calendar year, using the already-filtered authoritative ledger.
jq -r '[.date[0:4],.external_cash_flow,.analysis_class] | @tsv' "$INPUT_CAPITAL" |
awk -F '\t' '
{
 y=$1; cf=$2+0
 if(cf>0){yin[y]+=cf; gross_in+=cf; inflow_events[y]++}
 else if(cf<0){yout[y]+=(-cf); gross_out+=(-cf); outflow_events[y]++}
 ynet[y]+=cf
}
END {
 for(y in ynet) printf "%s\t%.10f\t%.10f\t%.10f\t%d\t%d\n",y,yin[y]+0,yout[y]+0,ynet[y]+0,inflow_events[y]+0,outflow_events[y]+0
 printf "%.10f\t%.10f\t%.10f\t%d\t%d\n",gross_in,gross_out,gross_in-gross_out,0,0 > "'"$TMP"'/capital_overall.tsv"
}' > "$TMP/capital_years.tsv"

# Merge trading and external-capital years.
awk -F '\t' '
FNR==NR {py[$1]=$2; c[$1]=$3; pr[$1]=$4; f[$1]=$5; ad[$1]=$6; years[$1]=1; next}
{yin[$1]=$2; yout[$1]=$3; ynet[$1]=$4; ie[$1]=$5; oe[$1]=$6; years[$1]=1}
END {
 for(y in years){
   dep=(yin[y]>0 ? c[y]/yin[y] : 0)
   pm=(yin[y]>0 ? pr[y]/yin[y] : 0)
   avg=(ad[y]>0 ? c[y]/ad[y] : 0)
   printf "%s\t%.10f\t%.10f\t%.10f\t%d\t%d\t%.10f\t%.10f\t%.10f\t%.10f\t%.10f\t%d\t%d\n",y,py[y]+0,c[y]+0,pr[y]+0,f[y]+0,ad[y]+0,yin[y]+0,yout[y]+0,ynet[y]+0,dep,pm,ie[y]+0,oe[y]+0
 }
}' "$TMP/trading_years.tsv" "$TMP/capital_years.tsv" | sort -k1,1 > "$TMP/merged_years.tsv"

awk -F '\t' '{printf "{\"year\":\"%s\",\"realized_pnl\":%.10f,\"matched_cost\":%.10f,\"matched_proceeds\":%.10f,\"fifo_fragments\":%d,\"active_sell_days\":%d,\"external_inflows\":%.10f,\"external_outflows\":%.10f,\"net_external_capital\":%.10f,\"deployment_multiple_vs_gross_inflows\":%s,\"proceeds_multiple_vs_gross_inflows\":%s,\"inflow_events\":%d,\"outflow_events\":%d}\n",$1,$2,$3,$4,$5,$6,$7,$8,$9,($7>0?sprintf("%.10f",$3/$7):"null"),($7>0?sprintf("%.10f",$4/$7):"null"),$12,$13}' "$TMP/merged_years.tsv" > "$YEARLY"

read -r PNL COST PROCEEDS FRAGMENTS ACTIVE_DAYS < "$TMP/overall.tsv"
read -r GROSS_IN GROSS_OUT NET_CAPITAL _ _ < "$TMP/capital_overall.tsv"
DEPLOY_MULT=$(awk -v c="$COST" -v i="$GROSS_IN" 'BEGIN{if(i)printf "%.10f",c/i;else print "null"}')
PROCEEDS_MULT=$(awk -v p="$PROCEEDS" -v i="$GROSS_IN" 'BEGIN{if(i)printf "%.10f",p/i;else print "null"}')
AVG_DEPLOY_DAY=$(awk -v c="$COST" -v d="$ACTIVE_DAYS" 'BEGIN{if(d)printf "%.10f",c/d;else print "null"}')
AVG_PROCEEDS_DAY=$(awk -v p="$PROCEEDS" -v d="$ACTIVE_DAYS" 'BEGIN{if(d)printf "%.10f",p/d;else print "null"}')
NET_MULT=$(awk -v c="$COST" -v n="$NET_CAPITAL" 'BEGIN{if(n)printf "%.10f",c/n;else print "null"}')

jq -n \
  --argjson realized_pnl "$PNL" \
  --argjson matched_cost "$COST" \
  --argjson matched_proceeds "$PROCEEDS" \
  --argjson fifo_fragments "$FRAGMENTS" \
  --argjson active_sell_days "$ACTIVE_DAYS" \
  --argjson gross_external_inflows "$GROSS_IN" \
  --argjson gross_external_outflows "$GROSS_OUT" \
  --argjson net_external_capital "$NET_CAPITAL" \
  --argjson deployment_multiple_vs_gross_inflows "$DEPLOY_MULT" \
  --argjson proceeds_multiple_vs_gross_inflows "$PROCEEDS_MULT" \
  --argjson deployment_multiple_vs_net_external_capital "$NET_MULT" \
  --argjson average_matched_cost_per_active_sell_day "$AVG_DEPLOY_DAY" \
  --argjson average_matched_proceeds_per_active_sell_day "$AVG_PROCEEDS_DAY" \
  '{analysis_scope:"realized FIFO fragments plus external capital ledger",capital_deployment:{matched_cost:$matched_cost,matched_proceeds:$matched_proceeds,realized_pnl:$realized_pnl,fifo_fragments:$fifo_fragments,active_sell_days:$active_sell_days,average_matched_cost_per_active_sell_day:$average_matched_cost_per_active_sell_day,average_matched_proceeds_per_active_sell_day:$average_matched_proceeds_per_active_sell_day},capital_velocity:{deployment_multiple_vs_gross_inflows:$deployment_multiple_vs_gross_inflows,proceeds_multiple_vs_gross_inflows:$proceeds_multiple_vs_gross_inflows,deployment_multiple_vs_net_external_capital:$deployment_multiple_vs_net_external_capital},external_capital:{gross_inflows:$gross_external_inflows,gross_outflows:$gross_external_outflows,net_external_capital:$net_external_capital},methodology:{deployment_multiple_vs_gross_inflows:"matched FIFO cost divided by gross external contributions; measures capital recycling relative to actual contributions",deployment_multiple_vs_net_external_capital:"matched FIFO cost divided by net external capital; useful as a capital-reuse diagnostic but can be distorted by withdrawals",active_sell_days:"number of distinct calendar days containing realized FIFO sales",scope_note:"does not infer daily cash balances or market-value exposure"}}' > "$SUMMARY"

jq -e . "$SUMMARY" >/dev/null
jq -e . "$YEARLY" >/dev/null
printf 'Wrote %s\nWrote %s\n' "$SUMMARY" "$YEARLY"
