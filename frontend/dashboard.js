const chartRegistry = Object.freeze({
  monthlyPerformance: {
    elementId: 'monthlyPerformanceChart',
    buildTraces: rows => {
      let cumulative = 0;
      const periods = rows.map(r => r.period);
      const pnl = rows.map(r => Number(r.realized_pnl));
      const cumulativePnl = pnl.map(v => (cumulative += v));
      return [
        { type: 'bar', x: periods, y: pnl, name: 'Monthly P&L', marker: { color: pnl.map(v => v >= 0 ? DASHBOARD_COLORS.positive : DASHBOARD_COLORS.negative) }, hovertemplate: '%{x}<br>P&L: $%{y:,.2f}<extra></extra>' },
        { type: 'scatter', mode: 'lines', x: periods, y: cumulativePnl, name: 'Cumulative P&L', line: { color: DASHBOARD_COLORS.info, width: 2.5 }, yaxis: 'y2', hovertemplate: '%{x}<br>Cumulative: $%{y:,.2f}<extra></extra>' }
      ];
    },
    layout: {
      height: 390, showlegend: true, legend: { orientation: 'h', x: 0, y: 1.08 },
      xaxis: { showgrid: false, tickangle: -45, tickfont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Monthly P&L ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis2: { title: 'Cumulative P&L ($)', overlaying: 'y', side: 'right', tickformat: '$,.0f', showgrid: false, titlefont: { color: DASHBOARD_COLORS.muted } }
    }
  },

  cumulativeRealizedPnl: {
    elementId: 'cumulativeRealizedPnlChart',
    buildTraces: rows => [{
      type: 'scatter', mode: 'lines',
      x: rows.map(r => r.date),
      y: rows.map(r => Number(r.cumulative_realized_pnl)),
      customdata: rows.map(r => [Number(r.realized_pnl), Number(r.drawdown), Number(r.fifo_fragments)]),
      line: { color: DASHBOARD_COLORS.info, width: 2.5 },
      hovertemplate: '<b>%{x}</b><br>Cumulative P&L: $%{y:,.2f}<br>Daily P&L: $%{customdata[0]:,.2f}<br>Drawdown: $%{customdata[1]:,.2f}<br>FIFO fragments: %{customdata[2]}<extra></extra>'
    }],
    layout: {
      height: 360, showlegend: false,
      margin: { l: 78, r: 24, t: 8, b: 52 },
      xaxis: { showgrid: false, tickfont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Cumulative realized P&L ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      shapes: [{ type: 'line', x0: 0, x1: 1, xref: 'paper', y0: 0, y1: 0, line: { color: DASHBOARD_COLORS.grid, width: 1 } }]
    }
  },
  dailyPnlDistribution: {
    elementId: 'dailyPnlDistributionChart',
    buildTraces: rows => {
      const values = rows.map(r => Number(r.realized_pnl)).filter(v => Math.abs(v) > 1e-9);
      return [{
        type: 'histogram',
        x: values,
        nbinsx: 12,
        marker: { color: DASHBOARD_COLORS.info },
        hovertemplate: 'Daily P&L: $%{x:,.2f}<br>Days: %{y}<extra></extra>'
      }];
    },
    layout: {
      height: 350, showlegend: false,
      margin: { l: 78, r: 24, t: 8, b: 52 },
      xaxis: { title: 'Daily realized P&L ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.muted, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Active sell days', dtick: 5, gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      shapes: [{ type: 'line', x0: 0, x1: 0, y0: 0, y1: 1, yref: 'paper', line: { color: DASHBOARD_COLORS.muted, width: 1 } }]
    }
  },
  grossProfitPareto: {
    elementId: 'grossProfitParetoChart',
    buildTraces: rows => {
      const bySymbol = new Map();
      rows.forEach(r => {
        const pnl = Number(r.realized_pnl);
        if (pnl > 0) bySymbol.set(r.symbol, (bySymbol.get(r.symbol) || 0) + pnl);
      });
      const sorted = [...bySymbol.entries()].sort((a, b) => b[1] - a[1]);
      const top = sorted.slice(0, 15);
      const other = sorted.slice(15).reduce((sum, [, value]) => sum + value, 0);
      if (other > 0) top.push(['Other profitable symbols', other]);
      const total = top.reduce((sum, [, value]) => sum + value, 0);
      let cumulative = 0;
      const labels = top.map(([symbol]) => symbol);
      const profits = top.map(([, value]) => value);
      const cumulativePct = profits.map(value => { cumulative += value; return cumulative / total * 100; });
      return [
        { type: 'bar', x: labels, y: profits, name: 'Gross profit', marker: { color: DASHBOARD_COLORS.positive }, hovertemplate: '<b>%{x}</b><br>Gross profit: $%{y:,.2f}<extra></extra>' },
        { type: 'scatter', mode: 'lines+markers', x: labels, y: cumulativePct, name: 'Cumulative share', yaxis: 'y2', line: { color: DASHBOARD_COLORS.info, width: 2.5 }, marker: { size: 6 }, hovertemplate: '<b>%{x}</b><br>Cumulative gross-profit share: %{y:.1f}%<extra></extra>' }
      ];
    },
    layout: {
      height: 390, showlegend: true, legend: { orientation: 'h', x: 0, y: 1.08 },
      margin: { l: 78, r: 70, t: 28, b: 70 },
      xaxis: { showgrid: false, tickangle: -45, tickfont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Gross profit ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis2: { title: 'Cumulative share (%)', overlaying: 'y', side: 'right', range: [0, 100], ticksuffix: '%', showgrid: false, titlefont: { color: DASHBOARD_COLORS.muted } }
    }
  },

  monthlyDrawdown: {
    elementId: 'monthlyDrawdownChart',
    buildTraces: rows => {
      let cumulative = 0;
      let peak = 0;
      const drawdown = rows.map(r => {
        cumulative += Number(r.realized_pnl);
        peak = Math.max(peak, cumulative);
        return cumulative - peak;
      });
      return [{
        type: 'scatter',
        mode: 'lines+markers',
        x: rows.map(r => r.period),
        y: drawdown,
        name: 'Drawdown',
        line: { color: DASHBOARD_COLORS.negative, width: 2.5 },
        fill: 'tozeroy',
        fillcolor: 'rgba(239,68,68,0.10)',
        hovertemplate: '%{x}<br>Drawdown: $%{y:,.2f}<extra></extra>'
      }];
    },
    layout: {
      height: 350,
      showlegend: false,
      margin: { l: 78, r: 24, t: 8, b: 52 },
      xaxis: { showgrid: false, tickangle: -45, tickfont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Drawdown ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } }
    }
  },

  fragmentReturnDistribution: {
    elementId: 'fragmentReturnDistributionChart',
    buildTraces: rows => {
      const winners = rows.map(r => Number(r.return_on_cost) * 100).filter(v => Number.isFinite(v) && v > 0);
      const losers = rows.map(r => Number(r.return_on_cost) * 100).filter(v => Number.isFinite(v) && v < 0);
      return [
        { type: 'histogram', x: winners, name: 'Profitable fragments', nbinsx: 18, marker: { color: DASHBOARD_COLORS.positive }, opacity: 0.72, hovertemplate: 'Return / cost: %{x:.2f}%<br>Fragments: %{y}<extra></extra>' },
        { type: 'histogram', x: losers, name: 'Losing fragments', nbinsx: 18, marker: { color: DASHBOARD_COLORS.negative }, opacity: 0.72, hovertemplate: 'Return / cost: %{x:.2f}%<br>Fragments: %{y}<extra></extra>' }
      ];
    },
    layout: {
      height: 360, barmode: 'overlay', showlegend: true, legend: { orientation: 'h', x: 0, y: 1.08 },
      margin: { l: 78, r: 24, t: 28, b: 52 },
      xaxis: { title: 'Return on FIFO fragment cost (%)', ticksuffix: '%', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.muted, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'FIFO fragments', dtick: 20, gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      shapes: [{ type: 'line', x0: 0, x1: 0, y0: 0, y1: 1, yref: 'paper', line: { color: DASHBOARD_COLORS.muted, width: 1 } }]
    }
  },

  holdingPeriodDistribution: {
    elementId: 'holdingPeriodDistributionChart',
    buildTraces: rows => [{
      type: 'histogram',
      x: rows.map(r => Number(r.holding_days)).filter(v => Number.isFinite(v) && v >= 0),
      nbinsx: 18,
      marker: { color: DASHBOARD_COLORS.info },
      hovertemplate: 'Holding period: %{x:.0f} days<br>Fragments: %{y}<extra></extra>'
    }],
    layout: {
      height: 350, showlegend: false,
      margin: { l: 78, r: 24, t: 8, b: 52 },
      xaxis: { title: 'Holding period (days)', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.muted, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'FIFO fragments', dtick: 20, gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } }
    }
  },
  tradeSizeOutcome: {
    elementId: 'tradeSizeOutcomeChart',
    buildTraces: rows => {
      const winners = rows.filter(r => Number(r.realized_pnl) > 0);
      const losers = rows.filter(r => Number(r.realized_pnl) < 0);
      const trace = (data, color, name) => ({
        type: 'scatter', mode: 'markers', name,
        x: data.map(r => Number(r.cost)),
        y: data.map(r => Number(r.realized_pnl)),
        customdata: data.map(r => [r.symbol, Number(r.holding_days), Number(r.return_on_cost) * 100]),
        marker: { color, size: 7, opacity: 0.68, line: { width: 0.5 } },
        hovertemplate: '<b>%{customdata[0]}</b><br>Cost: $%{x:,.2f}<br>Realized P&L: $%{y:,.2f}<br>Hold: %{customdata[1]:.0f} days<br>Return / cost: %{customdata[2]:.2f}%<extra></extra>'
      });
      return [trace(winners, DASHBOARD_COLORS.positive, 'Profitable fragments'), trace(losers, DASHBOARD_COLORS.negative, 'Losing fragments')];
    },
    layout: {
      height: 390, showlegend: true, legend: { orientation: 'h', x: 0, y: 1.08 },
      margin: { l: 78, r: 24, t: 28, b: 52 },
      xaxis: { title: 'FIFO fragment cost ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Realized P&L ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      shapes: [{ type: 'line', x0: 0, x1: 1, xref: 'paper', y0: 0, y1: 0, line: { color: DASHBOARD_COLORS.grid, width: 1 } }]
    }
  },
  holdingPeriodBucketOutcome: {
    elementId: 'holdingPeriodBucketOutcomeChart',
    buildTraces: rows => {
      const buckets = [
        { name: '< 7 days', min: 0, max: 7 },
        { name: '7–30 days', min: 7, max: 31 },
        { name: '31–90 days', min: 31, max: 91 },
        { name: '91–180 days', min: 91, max: 181 },
        { name: '> 180 days', min: 181, max: Infinity }
      ];
      const stats = buckets.map(b => ({ ...b, pnl: 0, fragments: 0, wins: 0 }));
      rows.forEach(r => {
        const h = Number(r.holding_days);
        const pnl = Number(r.realized_pnl);
        if (!Number.isFinite(h) || !Number.isFinite(pnl) || h < 0) return;
        const bucket = stats.find(b => h >= b.min && h < b.max);
        if (!bucket) return;
        bucket.pnl += pnl;
        bucket.fragments += 1;
        if (pnl > 0) bucket.wins += 1;
      });
      return [
        { type: 'bar', x: stats.map(r => r.name), y: stats.map(r => r.pnl), name: 'Realized P&L', marker: { color: stats.map(r => r.pnl >= 0 ? DASHBOARD_COLORS.positive : DASHBOARD_COLORS.negative) }, hovertemplate: '%{x}<br>Realized P&L: $%{y:,.2f}<extra></extra>' },
        { type: 'scatter', mode: 'lines+markers', x: stats.map(r => r.name), y: stats.map(r => r.fragments ? r.wins / r.fragments * 100 : 0), name: 'Win rate', yaxis: 'y2', line: { color: DASHBOARD_COLORS.info, width: 2.5 }, marker: { size: 7 }, hovertemplate: '%{x}<br>Win rate: %{y:.1f}%<extra></extra>' }
      ];
    },
    layout: {
      height: 360, showlegend: true, legend: { orientation: 'h', x: 0, y: 1.08 },
      margin: { l: 78, r: 70, t: 28, b: 52 },
      xaxis: { showgrid: false, tickfont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Realized P&L ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis2: { title: 'Win rate', overlaying: 'y', side: 'right', ticksuffix: '%', range: [0, 100], showgrid: false, titlefont: { color: DASHBOARD_COLORS.muted } }
    }
  },
  holdingPeriodOutcome: {
    elementId: 'holdingPeriodOutcomeChart',
    buildTraces: rows => {
      const winners = rows.filter(r => Number(r.realized_pnl) > 0);
      const losers = rows.filter(r => Number(r.realized_pnl) < 0);
      const trace = (data, color, name) => ({
        type: 'scatter', mode: 'markers', name,
        x: data.map(r => Number(r.holding_days)),
        y: data.map(r => Number(r.realized_pnl)),
        customdata: data.map(r => [r.symbol, Number(r.return_on_cost) * 100, Number(r.cost), r.buy_date, r.sell_date]),
        marker: { color, size: data.map(r => 5 + Math.min(14, Math.sqrt(Number(r.cost)) / 3)), opacity: 0.72, line: { width: 0.5 } },
        hovertemplate: '<b>%{customdata[0]}</b><br>Hold: %{x:.0f} days<br>Realized P&L: $%{y:,.2f}<br>Return / cost: %{customdata[1]:.2f}%<br>Cost: $%{customdata[2]:,.2f}<br>Buy: %{customdata[3]}<br>Sell: %{customdata[4]}<extra></extra>'
      });
      return [trace(winners, DASHBOARD_COLORS.positive, 'Profitable fragments'), trace(losers, DASHBOARD_COLORS.negative, 'Losing fragments')];
    },
    layout: {
      height: 390, showlegend: true, legend: { orientation: 'h', x: 0, y: 1.08 },
      margin: { l: 78, r: 24, t: 28, b: 52 },
      xaxis: { title: 'Holding period (days)', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Realized P&L ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      shapes: [
        { type: 'line', x0: 0, x1: 1, xref: 'paper', y0: 0, y1: 0, line: { color: DASHBOARD_COLORS.grid, width: 1 } },
        { type: 'line', x0: 0, x1: 0, xref: 'paper', y0: 0, y1: 1, yref: 'paper', line: { color: DASHBOARD_COLORS.grid, width: 1 } }
      ]
    }
  },
  monthlyTradeQuality: {
    elementId: 'monthlyTradeQualityChart',
    buildTraces: rows => [
      {
        type: 'scatter',
        mode: 'lines+markers',
        x: rows.map(r => r.period),
        y: rows.map(r => Number(r.win_rate) * 100),
        name: 'Win Rate',
        line: { color: DASHBOARD_COLORS.positive, width: 2.5 },
        marker: { size: 6 },
        hovertemplate: '%{x}<br>Win rate: %{y:.1f}%<extra></extra>'
      },
      {
        type: 'bar',
        x: rows.map(r => r.period),
        y: rows.map(r => Number(r.average_fragment_pnl)),
        name: 'Avg Fragment P&L',
        yaxis: 'y2',
        marker: { color: DASHBOARD_COLORS.info },
        hovertemplate: '%{x}<br>Avg fragment P&L: $%{y:.2f}<extra></extra>'
      }
    ],
    layout: {
      height: 350,
      showlegend: true,
      legend: { orientation: 'h', x: 0, y: 1.08 },
      xaxis: { showgrid: false, tickangle: -45, tickfont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Win Rate (%)', ticksuffix: '%', range: [0, 100], gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis2: { title: 'Avg Fragment P&L ($)', overlaying: 'y', side: 'right', tickformat: '$,.0f', showgrid: false, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } }
    }
  },
  monthlyTradeActivity: {
    elementId: 'monthlyTradeActivityChart',
    buildTraces: rows => [
      { type: 'bar', x: rows.map(r => r.period), y: rows.map(r => Number(r.winning_fragments)), name: 'Winning fragments', marker: { color: DASHBOARD_COLORS.positive }, hovertemplate: '%{x}<br>Winning fragments: %{y}<extra></extra>' },
      { type: 'bar', x: rows.map(r => r.period), y: rows.map(r => Number(r.losing_fragments)), name: 'Losing fragments', marker: { color: DASHBOARD_COLORS.negative }, hovertemplate: '%{x}<br>Losing fragments: %{y}<extra></extra>' }
    ],
    layout: {
      height: 350, barmode: 'stack', showlegend: true, legend: { orientation: 'h', x: 0, y: 1.08 },
      xaxis: { showgrid: false, tickangle: -45, tickfont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'FIFO fragments', dtick: 10, gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } }
    }
  },
  weekdayPerformance: {
    elementId: 'weekdayPerformanceChart',
    buildTraces: rows => {
      const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      const stats = names.map((name, i) => ({ name, index: i, pnl: 0, fragments: 0 }));
      rows.forEach(r => {
        const date = new Date(`${r.sell_date}T12:00:00`);
        const day = date.getDay();
        if (day >= 1 && day <= 5) {
          stats[day - 1].pnl += Number(r.realized_pnl);
          stats[day - 1].fragments += 1;
        }
      });
      return [
        { type: 'bar', x: stats.map(r => r.name), y: stats.map(r => r.pnl), name: 'Realized P&L', marker: { color: stats.map(r => r.pnl >= 0 ? DASHBOARD_COLORS.positive : DASHBOARD_COLORS.negative) }, hovertemplate: '%{x}<br>Realized P&L: $%{y:,.2f}<extra></extra>' },
        { type: 'scatter', mode: 'lines+markers', x: stats.map(r => r.name), y: stats.map(r => r.fragments), name: 'FIFO fragments', yaxis: 'y2', line: { color: DASHBOARD_COLORS.info, width: 2.5 }, marker: { size: 7 }, hovertemplate: '%{x}<br>FIFO fragments: %{y}<extra></extra>' }
      ];
    },
    layout: {
      height: 350, showlegend: true, legend: { orientation: 'h', x: 0, y: 1.08 },
      margin: { l: 78, r: 70, t: 28, b: 52 },
      xaxis: { showgrid: false, tickfont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Realized P&L ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis2: { title: 'FIFO fragments', overlaying: 'y', side: 'right', dtick: 20, showgrid: false, titlefont: { color: DASHBOARD_COLORS.muted } }
    }
  },

  fragmentPnlDistribution: {
    elementId: 'fragmentPnlDistributionChart',
    buildTraces: rows => {
      const winners = rows.map(r => Number(r.realized_pnl)).filter(v => v > 0);
      const losers = rows.map(r => Number(r.realized_pnl)).filter(v => v < 0);
      return [
        { type: 'histogram', x: winners, nbinsx: 16, name: 'Profitable fragments', marker: { color: DASHBOARD_COLORS.positive }, opacity: 0.78, hovertemplate: 'Realized P&L: $%{x:,.2f}<br>Fragments: %{y}<extra></extra>' },
        { type: 'histogram', x: losers, nbinsx: 10, name: 'Losing fragments', marker: { color: DASHBOARD_COLORS.negative }, opacity: 0.78, hovertemplate: 'Realized P&L: $%{x:,.2f}<br>Fragments: %{y}<extra></extra>' }
      ];
    },
    layout: {
      height: 350, barmode: 'overlay', showlegend: true, legend: { orientation: 'h', x: 0, y: 1.08 },
      margin: { l: 78, r: 24, t: 28, b: 52 },
      xaxis: { title: 'Realized FIFO P&L per fragment ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.muted, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'FIFO fragments', dtick: 20, gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } }
    }
  },

  monthlyProfitabilityQuality: {
    elementId: 'monthlyProfitabilityQualityChart',
    buildTraces: rows => [
      {
        type: 'bar',
        x: rows.map(r => r.period),
        y: rows.map(r => Number(r.profit_factor)),
        name: 'Profit Factor',
        marker: { color: DASHBOARD_COLORS.info },
        hovertemplate: '%{x}<br>Profit factor: %{y:.2f}<extra></extra>'
      },
      {
        type: 'scatter',
        mode: 'lines+markers',
        x: rows.map(r => r.period),
        y: rows.map(r => Number(r.return_on_matched_cost) * 100),
        name: 'Return / Matched Cost',
        yaxis: 'y2',
        line: { color: DASHBOARD_COLORS.positive, width: 2.5 },
        marker: { size: 6 },
        hovertemplate: '%{x}<br>Return: %{y:.2f}%<extra></extra>'
      }
    ],
    layout: {
      height: 350,
      showlegend: true,
      legend: { orientation: 'h', x: 0, y: 1.08 },
      xaxis: { showgrid: false, tickangle: -45, tickfont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Profit Factor', tickformat: '.1f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis2: { title: 'Return (%)', overlaying: 'y', side: 'right', ticksuffix: '%', showgrid: false, titlefont: { color: DASHBOARD_COLORS.muted } }
    }
  },
  yearlyPerformance: {
    elementId: 'yearlyPerformanceChart',
    buildTraces: rows => [
      { type: 'bar', x: rows.map(r => r.period), y: rows.map(r => Number(r.realized_pnl)), name: 'Realized P&L', marker: { color: DASHBOARD_COLORS.positive }, hovertemplate: '%{x}<br>P&L: $%{y:,.2f}<extra></extra>' },
      { type: 'scatter', mode: 'lines+markers', x: rows.map(r => r.period), y: rows.map(r => Number(r.return_on_matched_cost) * 100), name: 'Return / Matched Cost', yaxis: 'y2', line: { color: DASHBOARD_COLORS.info, width: 2.5 }, marker: { size: 7 }, hovertemplate: '%{x}<br>Return: %{y:.2f}%<extra></extra>' }
    ],
    layout: {
      height: 340, showlegend: true, legend: { orientation: 'h', x: 0, y: 1.08 },
      xaxis: { showgrid: false, tickfont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Realized P&L ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis2: { title: 'Return (%)', overlaying: 'y', side: 'right', ticksuffix: '%', showgrid: false, titlefont: { color: DASHBOARD_COLORS.muted } }
    }
  },
  symbolAttribution: {
    elementId: 'symbolAttributionChart',
    buildTraces: rows => {
      const sorted = [...rows].sort((a, b) => Number(a.realized_pnl) - Number(b.realized_pnl));
      return [{
        type: 'bar', orientation: 'h',
        x: sorted.map(r => Number(r.realized_pnl)),
        y: sorted.map(r => r.symbol),
        marker: { color: sorted.map(r => Number(r.realized_pnl) >= 0 ? DASHBOARD_COLORS.positive : DASHBOARD_COLORS.negative) },
        customdata: sorted.map(r => [r.fifo_fragments, r.winning_fragments, r.losing_fragments]),
        hovertemplate: '<b>%{y}</b><br>Realized P&L: $%{x:,.2f}<br>FIFO fragments: %{customdata[0]}<br>Wins / losses: %{customdata[1]} / %{customdata[2]}<extra></extra>'
      }];
    },
    layout: {
      height: 500, showlegend: false,
      margin: { l: 70, r: 24, t: 12, b: 42 },
      xaxis: { title: 'Realized P&L ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.muted, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { showgrid: false, tickfont: { color: DASHBOARD_COLORS.text } }
    }
  },

  openInventoryAge: {
    elementId: 'openInventoryAgeChart',
    buildTraces: rows => [{
      type: 'bar', orientation: 'h',
      x: rows.map(r => r.count), y: rows.map(r => r.label),
      marker: { color: DASHBOARD_COLORS.info },
      hovertemplate: '%{y}<br>Open lots: %{x}<extra></extra>'
    }],
    layout: {
      height: 320, showlegend: false,
      margin: { l: 88, r: 24, t: 8, b: 42 },
      xaxis: { title: 'Open lots', dtick: 5, gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { showgrid: false, tickfont: { color: DASHBOARD_COLORS.text } }
    }
  },
  capitalVelocity: {
    elementId: 'capitalVelocityChart',
    buildTraces: rows => [
      { type: 'bar', x: rows.map(r => r.year), y: rows.map(r => Number(r.matchedCost)), name: 'Matched FIFO Cost', marker: { color: DASHBOARD_COLORS.info }, hovertemplate: '%{x}<br>Matched cost: $%{y:,.0f}<extra></extra>' },
      { type: 'scatter', mode: 'lines+markers', x: rows.map(r => r.year), y: rows.map(r => Number(r.deploymentMultiple)), name: 'Deployment Multiple', yaxis: 'y2', line: { color: DASHBOARD_COLORS.positive, width: 2.5 }, marker: { size: 7 }, hovertemplate: '%{x}<br>Deployment: %{y:.2f}×<extra></extra>' }
    ],
    layout: {
      height: 360, showlegend: true, legend: { orientation: 'h', x: 0, y: 1.08 },
      xaxis: { showgrid: false, tickfont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Matched FIFO Cost ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis2: { title: 'Deployment Multiple', overlaying: 'y', side: 'right', ticksuffix: '×', showgrid: false, titlefont: { color: DASHBOARD_COLORS.muted } }
    }
  },
  openInventoryConcentration: {
    elementId: 'openInventoryConcentrationChart',
    buildTraces: rows => [{
      type: 'bar', orientation: 'h',
      x: rows.map(r => Number(r.costBasis)), y: rows.map(r => r.symbol),
      marker: { color: DASHBOARD_COLORS.positive },
      customdata: rows.map(r => [r.openLots, r.oldestLotAgeDays]),
      hovertemplate: '<b>%{y}</b><br>Cost basis: $%{x:,.2f}<br>Open lots: %{customdata[0]}<br>Oldest lot: %{customdata[1]} days<extra></extra>'
    }],
    layout: {
      height: 360, showlegend: false,
      margin: { l: 60, r: 24, t: 8, b: 42 },
      xaxis: { title: 'FIFO cost basis ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { showgrid: false, tickfont: { color: DASHBOARD_COLORS.text } }
    }
  },
  historicalConcentration: {
    elementId: 'historicalConcentrationChart',
    buildTraces: rows => [{
      type: 'bar', orientation: 'h',
      x: rows.map(r => Number(r.value)), y: rows.map(r => r.symbol),
      marker: { color: DASHBOARD_COLORS.info },
      hovertemplate: '<b>%{y}</b><br>Matched FIFO cost: $%{x:,.0f}<extra></extra>'
    }],
    layout: {
      height: 390, showlegend: false, margin: { l: 60, r: 24, t: 8, b: 42 },
      xaxis: { title: 'Matched FIFO cost ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { showgrid: false, tickfont: { color: DASHBOARD_COLORS.text } }
    }
  },
  symbolCapitalPnl: {
    elementId: 'symbolCapitalPnlChart',
    buildTraces: rows => [{
      type: 'scatter',
      mode: 'markers',
      x: rows.map(r => Number(r.matched_cost)),
      y: rows.map(r => Number(r.realized_pnl)),
      text: rows.map(r => r.symbol),
      customdata: rows.map(r => [Number(r.return_on_cost) * 100, Number(r.fifo_fragments)]),
      marker: {
        size: rows.map(r => 6 + Math.sqrt(Number(r.fifo_fragments)) * 2),
        color: rows.map(r => Number(r.realized_pnl) >= 0 ? DASHBOARD_COLORS.positive : DASHBOARD_COLORS.negative),
        line: { width: 1 }
      },
      hovertemplate: '<b>%{text}</b><br>Matched cost: $%{x:,.0f}<br>Realized P&L: $%{y:,.2f}<br>Return / cost: %{customdata[0]:.2f}%<br>FIFO fragments: %{customdata[1]}<extra></extra>'
    }],
    layout: {
      height: 380,
      showlegend: false,
      margin: { l: 78, r: 24, t: 8, b: 52 },
      xaxis: { title: 'Matched FIFO cost ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { title: 'Realized P&L ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      shapes: [{ type: 'line', x0: 0, x1: 1, xref: 'paper', y0: 0, y1: 0, line: { color: DASHBOARD_COLORS.grid, width: 1 } }]
    }
  },
  efficiencySymbol: { elementId:'efficiencySymbolChart', buildTraces: rows => { const sorted=[...rows].sort((a,b)=>Number(b.return_on_cost)-Number(a.return_on_cost)).slice(0,10).reverse(); return [{type:'bar',orientation:'h',x:sorted.map(r=>Number(r.return_on_cost)*100),y:sorted.map(r=>r.symbol),marker:{color:DASHBOARD_COLORS.info},customdata:sorted.map(r=>[r.realized_pnl,r.matched_cost]),hovertemplate:'<b>%{y}</b><br>Return / cost: %{x:.2f}%<br>Realized P&L: $%{customdata[0]:,.2f}<br>Matched cost: $%{customdata[1]:,.0f}<extra></extra>'}]}, layout:{height:360,showlegend:false,margin:{l:60,r:24,t:8,b:42},xaxis:{title:'Return on matched cost',ticksuffix:'%',gridcolor:DASHBOARD_COLORS.grid,zerolinecolor:DASHBOARD_COLORS.grid,titlefont:{color:DASHBOARD_COLORS.muted}},yaxis:{showgrid:false,tickfont:{color:DASHBOARD_COLORS.text}}} },
  efficiencyYearly:{elementId:'efficiencyYearlyChart',buildTraces:rows=>[{type:'bar',x:rows.map(r=>r.period),y:rows.map(r=>Number(r.return_on_matched_cost)*100),marker:{color:rows.map(r=>Number(r.return_on_matched_cost)>=0?DASHBOARD_COLORS.positive:DASHBOARD_COLORS.negative)},customdata:rows.map(r=>[r.realized_pnl,r.fifo_fragments]),hovertemplate:'<b>%{x}</b><br>Return / cost: %{y:.2f}%<br>Realized P&L: $%{customdata[0]:,.2f}<br>FIFO fragments: %{customdata[1]}<extra></extra>'}],layout:{height:360,showlegend:false,xaxis:{showgrid:false,tickfont:{color:DASHBOARD_COLORS.muted}},yaxis:{title:'Return (%)',ticksuffix:'%',gridcolor:DASHBOARD_COLORS.grid,zerolinecolor:DASHBOARD_COLORS.grid,titlefont:{color:DASHBOARD_COLORS.muted}}}},
  efficiencyMonthly:{elementId:'efficiencyMonthlyChart',buildTraces:rows=>[{type:'bar',x:rows.map(r=>r.period),y:rows.map(r=>Number(r.return_on_matched_cost)*100),marker:{color:rows.map(r=>Number(r.return_on_matched_cost)>=0?DASHBOARD_COLORS.positive:DASHBOARD_COLORS.negative)},hovertemplate:'<b>%{x}</b><br>Return / cost: %{y:.2f}%<extra></extra>'}],layout:{height:360,showlegend:false,xaxis:{showgrid:false,tickangle:-45,tickfont:{color:DASHBOARD_COLORS.muted}},yaxis:{title:'Return (%)',ticksuffix:'%',gridcolor:DASHBOARD_COLORS.grid,zerolinecolor:DASHBOARD_COLORS.grid,titlefont:{color:DASHBOARD_COLORS.muted}}}},
  grossLossConcentration: {
    elementId: 'grossLossConcentrationChart',
    buildTraces: rows => [{
      type: 'bar', orientation: 'h',
      x: rows.map(r => Number(r.value)), y: rows.map(r => r.symbol),
      marker: { color: DASHBOARD_COLORS.negative },
      hovertemplate: '<b>%{y}</b><br>Gross loss: $%{x:,.2f}<extra></extra>'
    }],
    layout: {
      height: 390, showlegend: false, margin: { l: 60, r: 24, t: 8, b: 42 },
      xaxis: { title: 'Gross loss ($)', tickformat: '$,.0f', gridcolor: DASHBOARD_COLORS.grid, zerolinecolor: DASHBOARD_COLORS.grid, titlefont: { color: DASHBOARD_COLORS.muted } },
      yaxis: { showgrid: false, tickfont: { color: DASHBOARD_COLORS.text } }
    }
  }
});

function money(value) { return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 2 }).format(value); }
function pct(value) { return `${(value * 100).toFixed(2)}%`; }
function setText(id, value) { document.getElementById(id).textContent = value; }

function renderRiskBehavior(risk) {
  setText('profitableMonths', `${risk.monthlyConsistency.profitableMonths} / ${risk.monthlyConsistency.activeMonths}`);
  setText('profitableMonthsDetail', `${risk.monthlyConsistency.profitableMonthPct.toFixed(1)}% profitable`);
  setText('riskDrawdown', money(risk.drawdown.maximum));
  setText('riskDrawdownDetail', `${risk.drawdown.episodes} episodes · all recovered`);
  setText('losingStreak', risk.streaks.maxLosingFragments.toLocaleString('en-US'));
  setText('winningStreak', risk.streaks.maxWinningFragments.toLocaleString('en-US'));
  setText('winnerHold', `${risk.holding.winningAverageDays.toFixed(1)} d`);
  setText('loserHold', `${risk.holding.losingAverageDays.toFixed(1)} d`);
  setText('longestRecovery', `${risk.drawdown.longestRecoveryDays} d`);
  setText('averageRecovery', `${risk.drawdown.averageRecoveryDays} d`);
  const holdMax = Math.max(risk.holding.winningAverageDays, risk.holding.losingAverageDays);
  document.getElementById('winnerHoldBar').style.width = `${risk.holding.winningAverageDays / holdMax * 100}%`;
  document.getElementById('loserHoldBar').style.width = `${risk.holding.losingAverageDays / holdMax * 100}%`;
  const recoveryMax = risk.drawdown.longestRecoveryDays;
  document.getElementById('longestRecoveryBar').style.width = '100%';
  document.getElementById('averageRecoveryBar').style.width = `${risk.drawdown.averageRecoveryDays / recoveryMax * 100}%`;
}


function renderCapitalVelocity(capital) {
  setText('capitalGrossInflows', money(capital.grossInflows));
  setText('capitalMatchedCost', money(capital.matchedCost));
  setText('capitalDeploymentMultiple', `${capital.deploymentMultiple.toFixed(2)}×`);
  setText('capitalActiveSellDays', capital.activeSellDays.toLocaleString('en-US'));
  setText('capitalNetCapitalMultiple', `${capital.netCapitalMultiple.toFixed(2)}×`);
  renderChartFromRegistry('capitalVelocity', capital.yearly);
}


function renderOpenInventory(inventory) {
  setText('openInventoryAsOf', `As of ${inventory.asOf}`);
  setText('openLots', inventory.inventory.openLots.toLocaleString('en-US'));
  setText('openSymbols', inventory.inventory.openSymbols.toLocaleString('en-US'));
  setText('openCostBasis', money(inventory.inventory.totalCostBasis));
  setText('openMedianAge', `${inventory.inventory.medianLotAgeDays.toFixed(1)} d`);
  setText('openOldestAge', `${inventory.inventory.oldestLotAgeDays.toLocaleString('en-US')} d`);
  setText('openConcentration', `${inventory.inventory.top5CostBasisSharePct.toFixed(1)}%`);
  renderChartFromRegistry('openInventoryAge', inventory.ageBuckets);
  renderChartFromRegistry('openInventoryConcentration', inventory.topSymbols);
}


function renderExposureConcentration(exposure) {
  setText('historicalTop1', `${exposure.historical.top1MatchedCostSharePct.toFixed(1)}%`);
  setText('historicalTop3', `${exposure.historical.top3MatchedCostSharePct.toFixed(1)}%`);
  setText('historicalTop5', `${exposure.historical.top5MatchedCostSharePct.toFixed(1)}%`);
  setText('historicalLossShare', `${exposure.historical.top5GrossLossSharePct.toFixed(1)}%`);
  setText('currentTop5Exposure', `${exposure.currentOpen.top5CostBasisSharePct.toFixed(1)}%`);
  renderChartFromRegistry('historicalConcentration', exposure.byMatchedCost);
  renderChartFromRegistry('grossLossConcentration', exposure.byGrossLoss);
}

function renderStrategyBehavior(s){const p=s.profile;setText('strategyWinRate',`${p.high_win_frequency.fifo_win_rate_pct.toFixed(2)}%`);setText('strategyPayoffRatio',`${p.payoff_asymmetry.winner_to_loser_abs_ratio.toFixed(2)}×`);setText('strategyMedianHold',`${p.holding_period_behavior.median_holding_days.toFixed(0)} d`);setText('strategyHoldRatio',`${p.holding_period_behavior.losing_to_winning_hold_ratio.toFixed(2)}×`);setText('strategyLossConcentration',`${p.concentration.top_5_gross_loss_share_pct.toFixed(1)}%`);setText('winnerRoc',`${p.payoff_asymmetry.winner_return_on_cost_pct.toFixed(2)}%`);setText('loserRoc',`${p.payoff_asymmetry.loser_return_on_cost_pct.toFixed(2)}%`);setText('strategyWinnerHold',`${p.holding_period_behavior.winning_average_holding_days.toFixed(1)} d`);setText('strategyLoserHold',`${p.holding_period_behavior.losing_average_holding_days.toFixed(1)} d`);const rm=Math.max(Math.abs(p.payoff_asymmetry.winner_return_on_cost_pct),Math.abs(p.payoff_asymmetry.loser_return_on_cost_pct));document.getElementById('winnerRocBar').style.width=`${Math.abs(p.payoff_asymmetry.winner_return_on_cost_pct)/rm*100}%`;document.getElementById('loserRocBar').style.width=`${Math.abs(p.payoff_asymmetry.loser_return_on_cost_pct)/rm*100}%`;const hm=Math.max(p.holding_period_behavior.winning_average_holding_days,p.holding_period_behavior.losing_average_holding_days);document.getElementById('strategyWinnerHoldBar').style.width=`${p.holding_period_behavior.winning_average_holding_days/hm*100}%`;document.getElementById('strategyLoserHoldBar').style.width=`${p.holding_period_behavior.losing_average_holding_days/hm*100}%`;setText('strategyOpenLots',p.current_inventory.open_lots.toLocaleString('en-US'));setText('strategyOpenSymbols',p.current_inventory.open_symbols.toLocaleString('en-US'));setText('strategyOpenCost',money(p.current_inventory.total_cost_basis));setText('strategyOldestLot',`${p.current_inventory.oldest_lot_age_days.toLocaleString('en-US')} d`)}
function renderTradeEfficiency(e){setText('effReturn',pct(e.efficiency.return_on_matched_cost));setText('effMedianRoc',pct(e.efficiency.median_fragment_return_on_cost));setText('effTurnover',`${e.efficiency.turnover_proceeds_to_cost.toFixed(4)}×`);setText('effAvgPnl',money(e.efficiency.average_fragment_pnl));setText('effPnlCapitalDay',`${(e.efficiency.pnl_per_capital_day*100).toFixed(4)}%`);renderChartFromRegistry('efficiencyYearly',e.yearly);renderChartFromRegistry('efficiencyMonthly',e.monthly);renderChartFromRegistry('efficiencySymbol',e.by_symbol);renderChartFromRegistry('symbolCapitalPnl',e.by_symbol);const h=e.efficiency.average_holding_days,s=DASHBOARD_DATA.strategyBehavior.profile.holding_period_behavior,m=Math.max(h,s.winning_average_holding_days,s.losing_average_holding_days);setText('effAvgHold',`${h.toFixed(1)} d`);setText('effWinnerHold',`${s.winning_average_holding_days.toFixed(1)} d`);setText('effLoserHold',`${s.losing_average_holding_days.toFixed(1)} d`);document.getElementById('effHoldBar').style.width=`${h/m*100}%`;document.getElementById('effWinnerHoldBar').style.width=`${s.winning_average_holding_days/m*100}%`;document.getElementById('effLoserHoldBar').style.width=`${s.losing_average_holding_days/m*100}%`}

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

document.addEventListener('DOMContentLoaded', () => {
  try {
    renderSummary(DASHBOARD_DATA.summary);
    renderChartFromRegistry('monthlyPerformance', DASHBOARD_DATA.monthly);
    renderChartFromRegistry('monthlyTradeQuality', DASHBOARD_DATA.monthly);
    renderChartFromRegistry('cumulativeRealizedPnl', DASHBOARD_DATA.daily);
    renderChartFromRegistry('dailyPnlDistribution', DASHBOARD_DATA.daily);
    renderChartFromRegistry('monthlyDrawdown', DASHBOARD_DATA.monthly);
    renderChartFromRegistry('monthlyProfitabilityQuality', DASHBOARD_DATA.monthly);
    renderChartFromRegistry('monthlyTradeActivity', DASHBOARD_DATA.monthly);
    renderChartFromRegistry('weekdayPerformance', DASHBOARD_DATA.fragments);
    renderChartFromRegistry('fragmentPnlDistribution', DASHBOARD_DATA.fragments);
    renderChartFromRegistry('yearlyPerformance', DASHBOARD_DATA.yearly);
    renderChartFromRegistry('symbolAttribution', [...DASHBOARD_DATA.symbolAttribution.contributors, ...DASHBOARD_DATA.symbolAttribution.detractors]);
    renderChartFromRegistry('grossProfitPareto', DASHBOARD_DATA.fragments);
    renderRiskBehavior(DASHBOARD_DATA.riskBehavior);
    renderOpenInventory(DASHBOARD_DATA.openInventory);
    renderCapitalVelocity(DASHBOARD_DATA.capitalVelocity);
    renderExposureConcentration(DASHBOARD_DATA.exposureConcentration);
    renderStrategyBehavior(DASHBOARD_DATA.strategyBehavior);
    renderTradeEfficiency(DASHBOARD_DATA.tradeEfficiency);
    renderChartFromRegistry('fragmentReturnDistribution', DASHBOARD_DATA.fragments);
    renderChartFromRegistry('holdingPeriodDistribution', DASHBOARD_DATA.fragments);
    renderChartFromRegistry('tradeSizeOutcome', DASHBOARD_DATA.fragments);
    renderChartFromRegistry('holdingPeriodOutcome', DASHBOARD_DATA.fragments);
    renderChartFromRegistry('holdingPeriodBucketOutcome', DASHBOARD_DATA.fragments);
    setText('status', '');
  } catch (error) {
    console.error(error);
    setText('status', `Dashboard load error: ${error.message}`);
  }
});
