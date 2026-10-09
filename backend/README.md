# Cash App Trading Analytics Backend

## Pipeline

`cash_app_report.csv` is the transaction source of truth.
`corporate_actions.json` is supplemental hand-maintained corporate-action configuration.

Run:

    make

This rebuilds the complete analytical pipeline and the external dashboard data artifact.

Validate:

    make check

## Refresh workflow

1. Replace/update `cash_app_report.csv`.
2. Run `make`.
3. Run `make check`.
4. Refresh the dashboard page.

The dashboard data is generated as `dashboard_data.js`, a separate external file loaded by the frontend. The transaction/analytics data is not embedded in `dashboard.html`.

## Main stages

CSV → JSONL → normalized transactions → FIFO lots/matches → performance → portfolio → risk/inventory/efficiency/capital/concentration/strategy → `dashboard_data.js`.

The Makefile is the authoritative orchestrator. Individual Bash scripts remain non-executable by project convention and are invoked with `source`.
