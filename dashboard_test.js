const DATA_FILES = Object.freeze({
  summary: 'performance_summary.json',
  monthly: 'trade_efficiency_monthly.jsonl'
});

const chartRegistry = Object.freeze({
  monthlyPerformance: {
    elementId: 'monthlyPerformanceChart',
    buildTraces: rows => {
      let cumulative = 0;
      const periods = rows.map(r => r.period);
      const pnl = rows.map(r => Number(r.realized_pnl));
      const cumulativePnl = pnl.map(v => (cumulative += v));

      return [
        {
          type: 'bar',
          x: periods,
          y: pnl,
          name: 'Monthly P&L',
          marker: { color: pnl.map(v => v >= 0 ? DASHBOARD_COLORS.positive : DASHBOARD_COLORS.negative) },
          hovertemplate: '%{x}<br>P&L: $%{y:,.2f}<extra></extra>'
        },
        {
          type: 'scatter',
          mode: 'lines',
          x: periods,
          y: cumulativePnl,
          name: 'Cumulative P&L',
          line: { color: DASHBOARD_COLORS.info, width: 2.5 },
          yaxis: 'y2',
          hovertemplate: '%{x}<br>Cumulative: $%{y:,.2f}<extra></extra>'
        }
      ];
    },
    layout: {
      height: 390,
      showlegend: true,
      legend: { orientation: 'h', x: 0, y: 1.08 },
      xaxis: {
        title: '',
        showgrid: false,
        tickangle: -45,
        tickfont: { color: DASHBOARD_COLORS.muted }
      },
      yaxis: {
        title: 'Monthly P&L ($)',
        tickformat: '$,.0f',
        gridcolor: DASHBOARD_COLORS.grid,
        zerolinecolor: DASHBOARD_COLORS.grid,
        titlefont: { color: DASHBOARD_COLORS.muted }
      },
      yaxis2: {
        title: 'Cumulative P&L ($)',
        overlaying: 'y',
        side: 'right',
        tickformat: '$,.0f',
        showgrid: false,
        titlefont: { color: DASHBOARD_COLORS.muted }
      }
    }
  }
});

function money(value) {
  return new Intl.NumberFormat('en-US', {
    style: 'currency', currency: 'USD', maximumFractionDigits: 2
  }).format(value);
}

function pct(value) {
  return `${(value * 100).toFixed(2)}%`;
}

function setText(id, value) {
  document.getElementById(id).textContent = value;
}

async function loadJson(path) {
  const response = await fetch(path);
  if (!response.ok) throw new Error(`Unable to load ${path}: ${response.status}`);
  return response.json();
}

async function loadJsonl(path) {
  const response = await fetch(path);
  if (!response.ok) throw new Error(`Unable to load ${path}: ${response.status}`);
  const text = await response.text();
  return text.trim().split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line));
}

function renderSummary(summary) {
  const t = summary.trading;
  const period = summary.analysis_period;

  setText('analysisPeriod', `${period.first_realized_day} → ${period.last_realized_day}`);
  setText('realizedPnl', money(t.realized_pnl));
  setText('returnOnCost', pct(t.return_on_matched_cost));
  setText('winRate', pct(t.win_rate));
  setText('profitFactor', t.profit_factor.toFixed(2));
  setText('matchedCost', money(t.matched_cost));
  setText('drawdown', money(t.max_realized_drawdown));
  setText('fragmentCount', t.fifo_fragments.toLocaleString('en-US'));
  setText('winLoss', `${t.wins} / ${t.losses}`);
}

async function initDashboard() {
  try {
    const [summary, monthly] = await Promise.all([
      loadJson(DATA_FILES.summary),
      loadJsonl(DATA_FILES.monthly)
    ]);

    renderSummary(summary);
    renderChartFromRegistry('monthlyPerformance', monthly);
  } catch (error) {
    console.error(error);
    setText('status', `Dashboard load error: ${error.message}`);
  }
}

document.addEventListener('DOMContentLoaded', initDashboard);
