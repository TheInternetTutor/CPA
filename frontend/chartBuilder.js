function renderChartFromRegistry(metricName, data) {
  const config = chartRegistry[metricName];
  if (!config) throw new Error(`Unknown chart registry metric: ${metricName}`);

  const traces = config.buildTraces(data);
  const layout = {
    ...config.layout,
    paper_bgcolor: 'transparent',
    plot_bgcolor: 'transparent',
    font: { color: DASHBOARD_COLORS.text, family: 'Inter, Segoe UI, sans-serif' },
    margin: { t: 28, r: 24, b: 48, l: 58 },
    hoverlabel: { bgcolor: DASHBOARD_COLORS.panel, bordercolor: DASHBOARD_COLORS.panelBorder }
  };

  Plotly.newPlot(config.elementId, traces, layout, {
    responsive: true,
    displaylogo: false,
    modeBarButtonsToRemove: ['lasso2d', 'select2d']
  });
}
