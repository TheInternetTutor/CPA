#!/bin/bash
# Cash App Portfolio Analysis — dashboard data assembly
# Non-executable by project convention; invoke with: source ./dashboard_data.sh [output_dir]

set -euo pipefail

OUT_DIR="${1:-.}"
OUT="${OUT_DIR}/dashboard_data.js"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for f in \
  performance_summary.json \
  trade_efficiency_monthly.jsonl \
  trade_efficiency_yearly.jsonl \
  exposure_concentration.json \
  risk_behavior.json \
  open_lot_analytics.json \
  capital_velocity.json \
  capital_velocity_yearly.jsonl \
  strategy_behavior.json \
  trade_efficiency.json \
  daily_performance.jsonl \
  trade_efficiency_fragments.jsonl; do
  [[ -f "$OUT_DIR/$f" ]] || { echo "Missing input: $OUT_DIR/$f" >&2; return 1 2>/dev/null || exit 1; }
done

jq -n \
  --slurpfile summary "$OUT_DIR/performance_summary.json" \
  --slurpfile monthly <(jq -s . "$OUT_DIR/trade_efficiency_monthly.jsonl") \
  --slurpfile yearly <(jq -s . "$OUT_DIR/trade_efficiency_yearly.jsonl") \
  --slurpfile exposure "$OUT_DIR/exposure_concentration.json" \
  --slurpfile risk "$OUT_DIR/risk_behavior.json" \
  --slurpfile open "$OUT_DIR/open_lot_analytics.json" \
  --slurpfile capital "$OUT_DIR/capital_velocity.json" \
  --slurpfile capital_yearly <(jq -s . "$OUT_DIR/capital_velocity_yearly.jsonl") \
  --slurpfile strategy "$OUT_DIR/strategy_behavior.json" \
  --slurpfile efficiency "$OUT_DIR/trade_efficiency.json" \
  --slurpfile daily <(jq -s . "$OUT_DIR/daily_performance.jsonl") \
  --slurpfile fragments <(jq -s . "$OUT_DIR/trade_efficiency_fragments.jsonl") \
  '
  ($summary[0]) as $s |
  ($monthly[0]) as $m |
  ($yearly[0]) as $y |
  ($exposure[0]) as $x |
  ($risk[0]) as $r |
  ($open[0]) as $o |
  ($capital[0]) as $c |
  ($capital_yearly[0]) as $cy |
  ($strategy[0]) as $st |
  ($efficiency[0]) as $e |
  ($daily[0]) as $d |
  ($fragments[0]) as $f |
  {
    summary: $s,
    daily: ($d | map({date,realized_pnl,matched_cost,proceeds,fifo_fragments,wins,losses,cumulative_realized_pnl,drawdown})),
    fragments: $f,
    monthly: $m,
    yearly: $y,
    symbolAttribution: {
      contributors: ($x.rankings.by_realized_pnl | map(select(.realized_pnl > 0)) | .[0:8]),
      detractors: ($x.rankings.by_gross_loss | map(select(.realized_pnl < 0)) | sort_by(.realized_pnl) | .[0:2]),
      source: "exposure_concentration.json",
      as_of: $x.analysis_as_of_date
    },
    riskBehavior: {
      streaks: {
        maxWinningFragments: $r.streaks_and_extremes.max_winning_fifo_fragment_streak,
        maxLosingFragments: $r.streaks_and_extremes.max_losing_fifo_fragment_streak,
        maxWinningDays: $r.daily_behavior.max_winning_day_streak,
        maxLosingDays: $r.daily_behavior.max_losing_day_streak
      },
      drawdown: {
        maximum: $r.daily_behavior.drawdown_summary.maximum_drawdown,
        episodes: $r.daily_behavior.drawdown_summary.number_of_drawdown_episodes,
        longestRecoveryDays: $r.daily_behavior.drawdown_summary.longest_recovery_days,
        averageRecoveryDays: $r.daily_behavior.drawdown_summary.average_recovery_days,
        unrecovered: $r.daily_behavior.drawdown_summary.unrecovered_drawdowns
      },
      monthlyConsistency: {
        activeMonths: $r.monthly_consistency.active_months,
        profitableMonths: $r.monthly_consistency.profitable_months,
        losingMonths: $r.monthly_consistency.losing_months,
        profitableMonthPct: $r.monthly_consistency.profitable_month_percentage
      },
      holding: {
        averageDays: $e.efficiency.average_holding_days,
        winningAverageDays: $e.efficiency.winning_average_holding_days,
        losingAverageDays: $e.efficiency.losing_average_holding_days,
        losingToWinningRatio: ($e.efficiency.losing_average_holding_days / $e.efficiency.winning_average_holding_days),
        medianDays: $e.efficiency.median_holding_days
      },
      extremes: {
        bestDay: {date: $r.daily_behavior.best_day.date, pnl: $r.daily_behavior.best_day.realized_pnl},
        worstDay: {date: $r.daily_behavior.worst_day.date, pnl: $r.daily_behavior.worst_day.realized_pnl},
        bestMonth: {period: $r.monthly_consistency.best_month.period, pnl: $r.monthly_consistency.best_month.realized_pnl},
        worstMonth: {period: $r.monthly_consistency.worst_month.period, pnl: $r.monthly_consistency.worst_month.realized_pnl}
      }
    },
    openInventory: {
      asOf: $o.analysis_as_of_date,
      inventory: {
        openLots: $o.inventory.open_lots,
        openSymbols: $o.inventory.open_symbols,
        totalQuantity: $o.inventory.total_quantity,
        totalCostBasis: $o.inventory.total_cost_basis,
        medianLotAgeDays: $o.inventory.median_lot_age_days,
        oldestLotAgeDays: $o.inventory.oldest_lot_age_days,
        top5CostBasisSharePct: $o.inventory.top_5_symbols_cost_basis_share_pct
      },
      ageBuckets: [
        {label:"< 7 days", count:$o.lot_age_buckets.under_7_days},
        {label:"7–30 days", count:$o.lot_age_buckets.days_7_to_30},
        {label:"31–90 days", count:$o.lot_age_buckets.days_31_to_90},
        {label:"91–180 days", count:$o.lot_age_buckets.days_91_to_180},
        {label:"181–365 days", count:$o.lot_age_buckets.days_181_to_365},
        {label:"> 365 days", count:$o.lot_age_buckets.over_365_days}
      ],
      topSymbols: ($o.by_symbol | .[0:10] | map({symbol,openLots:.open_lots,quantity,costBasis:.cost_basis,oldestLotAgeDays:.oldest_lot_age_days}))
    },
    capitalVelocity: {
      grossInflows: $c.external_capital.gross_inflows,
      grossOutflows: $c.external_capital.gross_outflows,
      netExternalCapital: $c.external_capital.net_external_capital,
      matchedCost: $c.capital_deployment.matched_cost,
      matchedProceeds: $c.capital_deployment.matched_proceeds,
      realizedPnl: $c.capital_deployment.realized_pnl,
      activeSellDays: $c.capital_deployment.active_sell_days,
      deploymentMultiple: $c.capital_velocity.deployment_multiple_vs_gross_inflows,
      proceedsMultiple: $c.capital_velocity.proceeds_multiple_vs_gross_inflows,
      netCapitalMultiple: $c.capital_velocity.deployment_multiple_vs_net_external_capital,
      yearly: ($cy | map({year,matchedCost:.matched_cost,matchedProceeds:.matched_proceeds,realizedPnl:.realized_pnl,externalInflows:.external_inflows,deploymentMultiple:.deployment_multiple_vs_gross_inflows}))
    },
    exposureConcentration: {
      asOf: $x.analysis_as_of_date,
      historical: {
        matchedCost: $x.historical.matched_cost,
        realizedPnl: $x.historical.realized_pnl,
        top1MatchedCostSharePct: $x.historical.top_1_matched_cost_share_pct,
        top3MatchedCostSharePct: $x.historical.top_3_matched_cost_share_pct,
        top5MatchedCostSharePct: $x.historical.top_5_matched_cost_share_pct,
        top1RealizedPnlSharePct: $x.historical.top_1_realized_pnl_share_pct,
        top3RealizedPnlSharePct: $x.historical.top_3_realized_pnl_share_pct,
        top5RealizedPnlSharePct: $x.historical.top_5_realized_pnl_share_pct,
        top5GrossProfitSharePct: $x.historical.top_5_gross_profit_share_pct,
        top5GrossLossSharePct: $x.historical.top_5_gross_loss_share_pct
      },
      currentOpen: {
        totalCostBasis: $x.current_open_inventory.total_cost_basis,
        openLots: $x.current_open_inventory.open_lots,
        openSymbols: $x.current_open_inventory.open_symbols,
        top1CostBasisSharePct: $x.current_open_inventory.top_1_cost_basis_share_pct,
        top3CostBasisSharePct: $x.current_open_inventory.top_3_cost_basis_share_pct,
        top5CostBasisSharePct: $x.current_open_inventory.top_5_cost_basis_share_pct
      },
      byMatchedCost: ($x.rankings.by_matched_cost | .[0:10] | map({symbol,value:.matched_cost})),
      byGrossLoss: ($x.rankings.by_gross_loss | .[0:10] | map({symbol,value:.gross_loss}))
    },
    strategyBehavior: $st,
    tradeEfficiency: {
      analysis_scope: $e.analysis_scope,
      efficiency: $e.efficiency,
      win_loss_efficiency: $e.win_loss_efficiency,
      by_symbol: $e.by_symbol,
      methodology: $e.methodology,
      monthly: $m,
      yearly: $y
    }
  }
  ' > "$TMP/dashboard_data.json"

jq -e . "$TMP/dashboard_data.json" >/dev/null
{
  printf 'const DASHBOARD_DATA = '
  cat "$TMP/dashboard_data.json"
  printf ';\nObject.freeze(DASHBOARD_DATA);\n'
} > "$OUT"

printf 'Wrote %s\n' "$OUT"
