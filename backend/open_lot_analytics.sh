#!/usr/bin/env bash
set -euo pipefail

INPUT_NORMALIZED=${1:?usage: open_lot_analytics.sh NORMALIZED.jsonl OPEN_LOTS.jsonl OUTPUT_DIR}
INPUT_OPEN_LOTS=${2:?usage: open_lot_analytics.sh NORMALIZED.jsonl OPEN_LOTS.jsonl OUTPUT_DIR}
OUTPUT_DIR=${3:-.}

command -v jq >/dev/null || { echo 'error: jq is required' >&2; return 1 2>/dev/null || exit 1; }
command -v awk >/dev/null || { echo 'error: awk is required' >&2; return 1 2>/dev/null || exit 1; }
command -v date >/dev/null || { echo 'error: date is required' >&2; return 1 2>/dev/null || exit 1; }
mkdir -p "$OUTPUT_DIR"

OUTPUT="$OUTPUT_DIR/open_lot_analytics.json"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# The analysis date is the latest dated transaction in the normalized source.
AS_OF=$(jq -r 'select(.date != null and .date != "") | .date[0:10]' "$INPUT_NORMALIZED" | sort | tail -1)
if [[ -z "$AS_OF" ]]; then
  echo 'error: could not determine analysis date from normalized transactions' >&2
  return 1 2>/dev/null || exit 1
fi

AS_OF_EPOCH=$(date -d "$AS_OF" +%s)

# Enrich every open lot with deterministic age and preserve the source row.
jq -r --arg asof "$AS_OF" '[.symbol,.buy_source_row,.buy_date,.quantity,.buy_price,.cost] | @tsv' "$INPUT_OPEN_LOTS" |
awk -F '\t' -v OFS='\t' -v asof_epoch="$AS_OF_EPOCH" '
function epoch_date(s,    cmd,x){cmd="date -d \"" substr(s,1,10) "\" +%s"; cmd|getline x; close(cmd); return x}
{
  symbol=$1; source_row=$2+0; buy_date=$3; qty=$4+0; price=$5+0; cost=$6+0
  age_days=(asof_epoch-epoch_date(buy_date))/86400
  if(age_days<0) age_days=0
  printf "%s\t%d\t%s\t%.10f\t%.10f\t%.10f\t%.10f\n",symbol,source_row,buy_date,qty,price,cost,age_days
}' > "$TMP/lots.tsv"

# Aggregate by symbol and compute inventory totals.
awk -F '\t' -v OFS='\t' '
{
  s=$1; row=$2; d=$3; q=$4+0; price=$5+0; c=$6+0; age=$7+0
  lots[s]++; qty[s]+=q; cost[s]+=c
  if (!(s in oldest) || d<oldest[s]) oldest[s]=d
  if (!(s in newest) || d>newest[s]) newest[s]=d
  if (!(s in oldest_age) || age>oldest_age[s]) oldest_age[s]=age
  if (!(s in newest_age) || age<newest_age[s]) newest_age[s]=age
}
END {
  for(s in lots) printf "%s\t%d\t%.10f\t%.10f\t%.10f\t%s\t%.10f\t%s\t%.10f\n",s,lots[s],qty[s],cost[s],cost[s]/qty[s],oldest[s],oldest_age[s],newest[s],newest_age[s]
}' "$TMP/lots.tsv" | sort -t $'\t' -k4,4nr > "$TMP/symbols.tsv"

# Inventory-wide statistics, age distribution, and concentration.
awk -F '\t' -v asof="$AS_OF" '
BEGIN {bucket_lt7=0; bucket_7_30=0; bucket_31_90=0; bucket_91_180=0; bucket_181_365=0; bucket_gt365=0}
{
  q=$4+0; c=$6+0; age=$7+0
  lots++
  qty+=q
  cost+=c
  ages[lots]=age
  if(age<7) bucket_lt7++
  else if(age<31) bucket_7_30++
  else if(age<91) bucket_31_90++
  else if(age<181) bucket_91_180++
  else if(age<366) bucket_181_365++
  else bucket_gt365++
  if(lots==1 || age>max_age) max_age=age
}
END {
  for(i=1;i<=lots;i++) sorted[i]=ages[i]
  for(i=2;i<=lots;i++){v=sorted[i];j=i-1;while(j>=1&&sorted[j]>v){sorted[j+1]=sorted[j];j--}sorted[j+1]=v}
  if(lots==0) median=0
  else if(lots%2) median=sorted[(lots+1)/2]
  else median=(sorted[lots/2]+sorted[lots/2+1])/2
  printf "%.10f\t%.10f\t%d\t%.10f\t%.10f\t%d\t%d\t%d\t%d\t%d\t%d\n",qty,cost,lots,(lots?cost/lots:0),median,max_age,bucket_lt7+0,bucket_7_30+0,bucket_31_90+0,bucket_91_180+0,bucket_181_365+0,bucket_gt365+0
}' "$TMP/lots.tsv" > "$TMP/totals.tsv"

# Build the final auditable JSON document.
read -r TOTAL_QTY TOTAL_COST TOTAL_LOTS AVG_LOT_COST MEDIAN_AGE MAX_AGE B0 B1 B2 B3 B4 B5 < "$TMP/totals.tsv"
B0=$(awk -F '\t' '($7+0)<7{n++} END{print n+0}' "$TMP/lots.tsv"); B1=$(awk -F '\t' '($7+0)>=7 && ($7+0)<31{n++} END{print n+0}' "$TMP/lots.tsv"); B2=$(awk -F '\t' '($7+0)>=31 && ($7+0)<91{n++} END{print n+0}' "$TMP/lots.tsv"); B3=$(awk -F '\t' '($7+0)>=91 && ($7+0)<181{n++} END{print n+0}' "$TMP/lots.tsv"); B4=$(awk -F '\t' '($7+0)>=181 && ($7+0)<366{n++} END{print n+0}' "$TMP/lots.tsv"); B5=$(awk -F '\t' '($7+0)>=366{n++} END{print n+0}' "$TMP/lots.tsv")
B0=${B0:-0}; B1=${B1:-0}; B2=${B2:-0}; B3=${B3:-0}; B4=${B4:-0}; B5=${B5:-0}
SYMBOL_COUNT=$(wc -l < "$TMP/symbols.tsv")
TOP5_COST=$(head -5 "$TMP/symbols.tsv" | awk -F '\t' '{s+=$4} END{printf "%.10f",s+0}')
TOP5_SHARE=$(awk -v x="$TOP5_COST" -v t="$TOTAL_COST" 'BEGIN{if(t) printf "%.10f",x/t*100; else printf "null"}')

{
  printf '['
  first=1
  while IFS=$'\t' read -r s n q c ac od oa nd na; do
    [[ -n "$s" ]] || continue
    esc=$(printf '%s' "$s" | jq -Rsa .)
    (( first )) || printf ','
    first=0
    printf '{"symbol":%s,"open_lots":%d,"quantity":%.10f,"cost_basis":%.10f,"average_cost_per_share":%.10f,"oldest_buy_date":"%s","oldest_lot_age_days":%.10f,"latest_buy_date":"%s","youngest_lot_age_days":%.10f}' "$esc" "$n" "$q" "$c" "$ac" "$od" "$oa" "$nd" "$na"
  done < "$TMP/symbols.tsv"
  printf ']\n'
} > "$TMP/symbols.json"

jq -n \
  --arg asof "$AS_OF" \
  --argjson total_open_lots "$TOTAL_LOTS" \
  --argjson open_symbols "$SYMBOL_COUNT" \
  --argjson total_quantity "$TOTAL_QTY" \
  --argjson total_cost_basis "$TOTAL_COST" \
  --argjson average_lot_cost "$AVG_LOT_COST" \
  --argjson median_lot_age_days "$MEDIAN_AGE" \
  --argjson oldest_lot_age_days "$MAX_AGE" \
  --argjson top5_cost_basis_share_pct "$TOP5_SHARE" \
  --argjson bucket_lt7 "$B0" \
  --argjson bucket_7_30 "$B1" \
  --argjson bucket_31_90 "$B2" \
  --argjson bucket_91_180 "$B3" \
  --argjson bucket_181_365 "$B4" \
  --argjson bucket_gt365 "$B5" \
  --slurpfile symbols "$TMP/symbols.json" \
  '{
    analysis_scope: "open FIFO inventory only",
    analysis_as_of_date: $asof,
    inventory: {
      open_lots: $total_open_lots,
      open_symbols: $open_symbols,
      total_quantity: $total_quantity,
      total_cost_basis: $total_cost_basis,
      average_cost_basis_per_lot: $average_lot_cost,
      median_lot_age_days: $median_lot_age_days,
      oldest_lot_age_days: $oldest_lot_age_days,
      top_5_symbols_cost_basis_share_pct: $top5_cost_basis_share_pct
    },
    lot_age_buckets: {
      under_7_days: $bucket_lt7,
      days_7_to_30: $bucket_7_30,
      days_31_to_90: $bucket_31_90,
      days_91_to_180: $bucket_91_180,
      days_181_to_365: $bucket_181_365,
      over_365_days: $bucket_gt365
    },
    by_symbol: $symbols[0],
    notes: [
      "Cost basis is derived from the remaining FIFO open lots.",
      "Market value and unrealized P&L are intentionally not calculated because historical/current mark prices are not part of the source dataset.",
      "Lot age is measured from buy date through the latest transaction date in the normalized source data."
    ]
  }' > "$OUTPUT"

jq -e . "$OUTPUT" >/dev/null
printf 'Wrote %s\n' "$OUTPUT"
