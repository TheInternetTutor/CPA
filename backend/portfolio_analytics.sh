#!/usr/bin/env bash
set -euo pipefail

INPUT_NORMALIZED=${1:?usage: portfolio_analytics.sh NORMALIZED.jsonl MATCHES.jsonl OUTPUT_DIR}
INPUT_MATCHES=${2:?usage: portfolio_analytics.sh NORMALIZED.jsonl MATCHES.jsonl OUTPUT_DIR}
OUTPUT_DIR=${3:-.}

command -v jq >/dev/null || { echo 'error: jq is required' >&2; exit 1; }
command -v awk >/dev/null || { echo 'error: awk is required' >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"

MONTHLY="$OUTPUT_DIR/monthly_performance.jsonl"
YEARLY="$OUTPUT_DIR/yearly_performance.jsonl"
CAPITAL="$OUTPUT_DIR/external_capital.jsonl"
TRADE_STATS="$OUTPUT_DIR/trading_statistics.json"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Period P&L from FIFO matched fragments.
jq -r '[.sell_date[0:10], .realized_pnl, .cost, .proceeds, .quantity] | @tsv' "$INPUT_MATCHES" |
awk -F '\t' '
function period(d,n){return substr(d,1,n)}
{
 d=$1; p=$2+0; c=$3+0; pr=$4+0; q=$5+0
 m=period(d,7); y=period(d,4)
 mpnl[m]+=p; mcost[m]+=c; mproceeds[m]+=pr; mfrags[m]++; if(p>0) mwins[m]++; else if(p<0) mlosses[m]++
 ypnl[y]+=p; ycost[y]+=c; yproceeds[y]+=pr; yfrags[y]++; if(p>0) ywins[y]++; else if(p<0) ylosses[y]++
}
END {
 for(m in mpnl) printf "M\t%s\t%.10f\t%.10f\t%.10f\t%d\t%d\t%d\n",m,mpnl[m],mcost[m],mproceeds[m],mfrags[m],mwins[m]+0,mlosses[m]+0
 for(y in ypnl) printf "Y\t%s\t%.10f\t%.10f\t%.10f\t%d\t%d\t%d\n",y,ypnl[y],ycost[y],yproceeds[y],yfrags[y],ywins[y]+0,ylosses[y]+0
}' | sort -k1,1 -k2,2 > "$TMP/periods.tsv"

awk -F '\t' '$1=="M"{printf "{\"period\":\"%s\",\"realized_pnl\":%.10f,\"matched_cost\":%.10f,\"proceeds\":%.10f,\"fifo_fragments\":%d,\"wins\":%d,\"losses\":%d}\n",$2,$3,$4,$5,$6,$7,$8}' "$TMP/periods.tsv" > "$MONTHLY"
awk -F '\t' '$1=="Y"{printf "{\"year\":\"%s\",\"realized_pnl\":%.10f,\"matched_cost\":%.10f,\"proceeds\":%.10f,\"fifo_fragments\":%d,\"wins\":%d,\"losses\":%d}\n",$2,$3,$4,$5,$6,$7,$8}' "$TMP/periods.tsv" > "$YEARLY"

# External capital ledger, preserving every qualifying source row.
jq -c 'select(.external_cash_flow != 0) | {date:.date,analysis_class:.analysis_class,transaction_type:.transaction_type,status:.status,amount:.amount_value,external_cash_flow:.external_cash_flow,notes:.notes,source_row:.source_row}' "$INPUT_NORMALIZED" > "$CAPITAL"

# Matched-fragment trading statistics, including holding time and trade-size distribution.
jq -r '[.buy_date[0:10], .sell_date[0:10], .realized_pnl, .cost, .proceeds] | @tsv' "$INPUT_MATCHES" |
awk -F '\t' '
function epoch(d){cmd="date -d " d " +%s"; cmd|getline x; close(cmd); return x}
{
 b=$1; s=$2; p=$3+0; c=$4+0; pr=$5+0
 bd=epoch(b); sd=epoch(s); hold=(sd-bd)/86400
 n++; holds[n]=hold; total_hold+=hold
 if(p>0){wins++; win_pnl+=p; win_hold+=hold} else if(p<0){losses++; loss_pnl+=p; loss_hold+=hold}
}
END {
 if(n==0){print "{}"; exit}
 for(i=1;i<=n;i++) sorted[i]=holds[i]
 # insertion sort for portable awk
 for(i=2;i<=n;i++){v=sorted[i];j=i-1;while(j>=1&&sorted[j]>v){sorted[j+1]=sorted[j];j--}sorted[j+1]=v}
 if(n%2) median=sorted[(n+1)/2]; else median=(sorted[n/2]+sorted[n/2+1])/2
 avg=total_hold/n
 printf "{\"matched_fragments\":%d,\"winning_fragments\":%d,\"losing_fragments\":%d,\"average_holding_days\":%.10f,\"median_holding_days\":%.10f,\"winning_average_holding_days\":%.10f,\"losing_average_holding_days\":%.10f}\n",n,wins,losses,avg,(median+0),wins?win_hold/wins:0,losses?loss_hold/losses:0
}' > "$TRADE_STATS"

jq -e . "$TRADE_STATS" >/dev/null
jq -e . "$MONTHLY" >/dev/null
jq -e . "$YEARLY" >/dev/null
jq -e . "$CAPITAL" >/dev/null

printf 'Wrote %s\nWrote %s\nWrote %s\nWrote %s\n' "$MONTHLY" "$YEARLY" "$CAPITAL" "$TRADE_STATS"
