#!/bin/bash
# Source this script to build historical and current concentration analytics.
# Usage: source ./exposure_concentration.sh [fragments] [open_analytics] [output_dir]

FRAGMENTS=${1:-trade_efficiency_fragments.jsonl}
OPEN_ANALYTICS=${2:-open_lot_analytics.json}
OUTDIR=${3:-.}

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; return 1 2>/dev/null || exit 1; }
[ -f "$FRAGMENTS" ] || { echo "ERROR: missing $FRAGMENTS" >&2; return 1 2>/dev/null || exit 1; }
[ -f "$OPEN_ANALYTICS" ] || { echo "ERROR: missing $OPEN_ANALYTICS" >&2; return 1 2>/dev/null || exit 1; }
mkdir -p "$OUTDIR"

SYMBOLS="$OUTDIR/exposure_concentration_symbols.jsonl"
SUMMARY="$OUTDIR/exposure_concentration.json"

jq -s '
  group_by(.symbol)
  | map({
      symbol: .[0].symbol,
      matched_cost: (map(.cost) | add),
      matched_proceeds: (map(.proceeds) | add),
      realized_pnl: (map(.realized_pnl) | add),
      gross_profit: (map(select(.realized_pnl > 0) | .realized_pnl) | add // 0),
      gross_loss: (map(select(.realized_pnl < 0) | .realized_pnl) | add // 0),
      fifo_fragments: length,
      winning_fragments: (map(select(.realized_pnl > 0)) | length),
      losing_fragments: (map(select(.realized_pnl < 0)) | length)
    })
  | sort_by(-.matched_cost)
  | .[]
' "$FRAGMENTS" > "$SYMBOLS" || return 1

jq -n --slurpfile rows "$SYMBOLS" --slurpfile open "$OPEN_ANALYTICS" '
  ($rows) as $r
  | ($open[0]) as $o
  | ($r | map(.matched_cost) | add) as $total_cost
  | ($r | map(.gross_profit) | add) as $gross_profit
  | ($r | map(.gross_loss) | add) as $gross_loss
  | ($r | map(.realized_pnl) | add) as $net
  | ($o.by_symbol | map({symbol, cost_basis}) | sort_by(-.cost_basis)) as $open_ranked
  | {
      analysis_scope: "historical FIFO trading concentration plus current open FIFO cost-basis concentration",
      analysis_as_of_date: $o.analysis_as_of_date,
      historical: {
        matched_cost: $total_cost,
        realized_pnl: $net,
        gross_profit: $gross_profit,
        gross_loss: $gross_loss,
        top_1_matched_cost_share_pct: (($r[0].matched_cost / $total_cost) * 100),
        top_3_matched_cost_share_pct: (($r[0:3] | map(.matched_cost) | add / $total_cost) * 100),
        top_5_matched_cost_share_pct: (($r[0:5] | map(.matched_cost) | add / $total_cost) * 100),
        top_1_realized_pnl_share_pct: (($r | sort_by(-.realized_pnl) | .[0].realized_pnl / $net) * 100),
        top_3_realized_pnl_share_pct: (($r | sort_by(-.realized_pnl) | .[0:3] | map(.realized_pnl) | add / $net) * 100),
        top_5_realized_pnl_share_pct: (($r | sort_by(-.realized_pnl) | .[0:5] | map(.realized_pnl) | add / $net) * 100),
        top_5_gross_profit_share_pct: (($r | sort_by(-.gross_profit) | .[0:5] | map(.gross_profit) | add / $gross_profit) * 100),
        top_5_gross_loss_share_pct: (($r | sort_by(.gross_loss) | .[0:5] | map(.gross_loss) | add / $gross_loss) * 100)
      },
      current_open_inventory: {
        total_cost_basis: $o.inventory.total_cost_basis,
        open_lots: $o.inventory.open_lots,
        open_symbols: $o.inventory.open_symbols,
        top_1_cost_basis_share_pct: (($open_ranked[0].cost_basis / $o.inventory.total_cost_basis) * 100),
        top_3_cost_basis_share_pct: (($open_ranked[0:3] | map(.cost_basis) | add / $o.inventory.total_cost_basis) * 100),
        top_5_cost_basis_share_pct: (($open_ranked[0:5] | map(.cost_basis) | add / $o.inventory.total_cost_basis) * 100)
      },
      rankings: {
        by_matched_cost: $r[0:10],
        by_realized_pnl: ($r | sort_by(-.realized_pnl) | .[0:10]),
        by_gross_loss: ($r | sort_by(.gross_loss) | .[0:10]),
        open_inventory_by_cost_basis: $open_ranked[0:10]
      }
    }
' > "$SUMMARY" || return 1

jq -e . "$SUMMARY" >/dev/null || return 1
jq -e . "$SYMBOLS" >/dev/null || return 1

echo "Exposure concentration analytics written to $SUMMARY and $SYMBOLS"
