#!/bin/bash
# Cash App Portfolio Analysis — strategy behavior synthesis
# Non-executable by project convention; invoke with: source ./strategy_behavior.sh [output_dir]

set -euo pipefail

OUT_DIR="${1:-.}"
RISK="${OUT_DIR}/risk_behavior.json"
EFF="${OUT_DIR}/trade_efficiency.json"
VEL="${OUT_DIR}/capital_velocity.json"
OPEN="${OUT_DIR}/open_lot_analytics.json"
EXPOSURE="${OUT_DIR}/exposure_concentration.json"
SUMMARY="${OUT_DIR}/performance_summary.json"
OUT="${OUT_DIR}/strategy_behavior.json"

for f in "$RISK" "$EFF" "$VEL" "$OPEN" "$EXPOSURE" "$SUMMARY"; do
  [[ -f "$f" ]] || { echo "Missing input: $f" >&2; return 1 2>/dev/null || exit 1; }
done

jq -n \
  --slurpfile r "$RISK" \
  --slurpfile e "$EFF" \
  --slurpfile v "$VEL" \
  --slurpfile o "$OPEN" \
  --slurpfile x "$EXPOSURE" \
  --slurpfile p "$SUMMARY" \
  '
  ($r[0]) as $r |
  ($e[0]) as $e |
  ($v[0]) as $v |
  ($o[0]) as $o |
  ($x[0]) as $x |
  ($p[0]) as $p |
  {
    analysis_scope: "descriptive synthesis of validated FIFO, risk, efficiency, capital-velocity, concentration, and open-inventory layers",
    profile: {
      high_win_frequency: {
        fifo_win_rate_pct: (100 * $p.trading.win_rate),
        note: "Overall FIFO win rate is taken from the validated performance layer; this synthesis does not recompute it from net daily P&L."
      },
      payoff_asymmetry: {
        average_win: $e.win_loss_efficiency.average_win,
        average_loss: $e.win_loss_efficiency.average_loss,
        winner_to_loser_abs_ratio: (($e.win_loss_efficiency.average_win) / (-$e.win_loss_efficiency.average_loss)),
        winner_return_on_cost_pct: (100 * $e.win_loss_efficiency.winner_return_on_cost),
        loser_return_on_cost_pct: (100 * $e.win_loss_efficiency.loser_return_on_cost)
      },
      holding_period_behavior: {
        average_holding_days: $e.efficiency.average_holding_days,
        winning_average_holding_days: $e.efficiency.winning_average_holding_days,
        losing_average_holding_days: $e.efficiency.losing_average_holding_days,
        losing_to_winning_hold_ratio: ($e.efficiency.losing_average_holding_days / $e.efficiency.winning_average_holding_days),
        median_holding_days: $e.efficiency.median_holding_days,
        note: "Longer losing holds are descriptive; the dataset does not establish the reason for the difference."
      },
      capital_recycling: {
        matched_cost: $v.capital_deployment.matched_cost,
        gross_external_inflows: $v.external_capital.gross_inflows,
        deployment_multiple_vs_gross_inflows: $v.capital_velocity.deployment_multiple_vs_gross_inflows,
        active_sell_days: $v.capital_deployment.active_sell_days
      },
      concentration: {
        top_5_matched_cost_share_pct: $x.historical.top_5_matched_cost_share_pct,
        top_5_realized_pnl_share_pct: $x.historical.top_5_realized_pnl_share_pct,
        top_5_gross_loss_share_pct: $x.historical.top_5_gross_loss_share_pct,
        top_5_open_cost_basis_share_pct: $o.inventory.top_5_symbols_cost_basis_share_pct
      },
      current_inventory: {
        open_lots: $o.inventory.open_lots,
        open_symbols: $o.inventory.open_symbols,
        total_cost_basis: $o.inventory.total_cost_basis,
        median_lot_age_days: $o.inventory.median_lot_age_days,
        oldest_lot_age_days: $o.inventory.oldest_lot_age_days
      }
    },
    strengths: [
      "High realized-trade win frequency and positive monthly consistency are supported by the validated FIFO and monthly layers.",
      "Average winning fragments are larger than average losing fragments, while winner returns on cost exceed loser losses in absolute percentage terms.",
      "Capital is heavily recycled: matched trading cost substantially exceeds gross external contributions.",
      "Historical realized P&L is broadly distributed across contributors even though trading capital is concentrated in a smaller group of symbols."
    ],
    watchpoints: [
      "Losing FIFO fragments remain open materially longer than winning fragments on average.",
      "A relatively small group of symbols accounts for a disproportionate share of gross losses.",
      "Current open inventory contains older lots, including lots older than one year, so realized-trade efficiency does not describe all capital currently tied up.",
      "No causal explanation is assigned to these behaviors because the CSV does not contain decision rationale or market-state annotations."
    ],
    source_layers: ["risk_behavior.json", "trade_efficiency.json", "capital_velocity.json", "exposure_concentration.json", "open_lot_analytics.json"]
  }
  ' > "$OUT"

jq -e . "$OUT" >/dev/null
