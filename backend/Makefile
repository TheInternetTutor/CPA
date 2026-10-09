# Cash App Portfolio Analysis
# Source transaction ledger: cashapp_report.csv
# Supplemental configuration: corporate_actions.json
# Everything else is generated.

SHELL := /bin/bash

CSV ?= cashapp_report.csv
JSONL ?= cashapp_report.jsonl
NORMALIZED ?= cashapp_report.normalized.jsonl
ACTIONS ?= corporate_actions.json
MATCHES ?= fifo_matches.jsonl
OPEN_LOTS ?= fifo_open_lots.jsonl
WARNINGS ?= fifo_open_lots.warnings.log

DAILY ?= daily_performance.jsonl
ROLLING ?= rolling_performance.jsonl
SYMBOLS ?= symbol_attribution.json
SUMMARY ?= performance_summary.json
MONTHLY ?= monthly_performance.jsonl
YEARLY ?= yearly_performance.jsonl
CAPITAL ?= external_capital.jsonl
TRADE_STATS ?= trading_statistics.json

RISK ?= risk_behavior.json
OPEN_ANALYTICS ?= open_lot_analytics.json
EFFICIENCY ?= trade_efficiency.json
EFFICIENCY_FRAGMENTS ?= trade_efficiency_fragments.jsonl
EFFICIENCY_MONTHLY ?= trade_efficiency_monthly.jsonl
EFFICIENCY_YEARLY ?= trade_efficiency_yearly.jsonl
CAPITAL_VELOCITY ?= capital_velocity.json
CAPITAL_VELOCITY_YEARLY ?= capital_velocity_yearly.jsonl
EXPOSURE ?= exposure_concentration.json
EXPOSURE_SYMBOLS ?= exposure_concentration_symbols.jsonl
STRATEGY_BEHAVIOR ?= strategy_behavior.json
DASHBOARD_DATA ?= dashboard_data.js

PERFORMANCE_SCRIPT ?= performance_metrics.sh

.PHONY: all data fifo metrics performance portfolio risk inventory efficiency time-efficiency capital-velocity exposure strategy-behavior dashboard-data check clean jsonl-to-json

# The complete pipeline. Plain `make` rebuilds everything whose inputs changed.
all: dashboard-data

data: $(NORMALIZED)
fifo: $(MATCHES) $(OPEN_LOTS)
metrics: performance
performance: $(DAILY) $(ROLLING) $(SYMBOLS) $(SUMMARY)
portfolio: metrics $(MONTHLY) $(YEARLY) $(CAPITAL) $(TRADE_STATS) $(RISK) $(OPEN_ANALYTICS) $(EFFICIENCY) $(EFFICIENCY_FRAGMENTS) $(EFFICIENCY_MONTHLY) $(EFFICIENCY_YEARLY) $(CAPITAL_VELOCITY) $(CAPITAL_VELOCITY_YEARLY) $(EXPOSURE) $(EXPOSURE_SYMBOLS) $(STRATEGY_BEHAVIOR)
risk: $(RISK)
inventory: $(OPEN_ANALYTICS)
efficiency: $(EFFICIENCY) $(EFFICIENCY_FRAGMENTS)
time-efficiency: $(EFFICIENCY_MONTHLY) $(EFFICIENCY_YEARLY)
capital-velocity: $(CAPITAL_VELOCITY) $(CAPITAL_VELOCITY_YEARLY)
exposure: $(EXPOSURE) $(EXPOSURE_SYMBOLS)
strategy-behavior: $(STRATEGY_BEHAVIOR)
dashboard-data: $(DASHBOARD_DATA)

$(JSONL): $(CSV) csv_to_jsonl.sh
	source ./csv_to_jsonl.sh "$(CSV)" "$(JSONL)"
	jq -e . "$(JSONL)" >/dev/null

$(NORMALIZED): $(JSONL) normalize_transactions.sh
	source ./normalize_transactions.sh "$(JSONL)" "$(NORMALIZED)"
	jq -e . "$(NORMALIZED)" >/dev/null

$(MATCHES) $(OPEN_LOTS): $(NORMALIZED) fifo_lots.sh $(ACTIONS)
	source ./fifo_lots.sh "$(NORMALIZED)" "$(MATCHES)" "$(OPEN_LOTS)" "$(WARNINGS)"
	jq -e . "$(MATCHES)" >/dev/null
	jq -e . "$(OPEN_LOTS)" >/dev/null

$(DAILY) $(ROLLING) $(SYMBOLS) $(SUMMARY): $(NORMALIZED) $(MATCHES) $(PERFORMANCE_SCRIPT)
	source ./$(PERFORMANCE_SCRIPT) "$(NORMALIZED)" "$(MATCHES)" .
	jq -e . "$(DAILY)" >/dev/null
	jq -e . "$(ROLLING)" >/dev/null
	jq -e . "$(SYMBOLS)" >/dev/null
	jq -e . "$(SUMMARY)" >/dev/null

$(MONTHLY) $(YEARLY) $(CAPITAL) $(TRADE_STATS): $(NORMALIZED) $(MATCHES) portfolio_analytics.sh
	source ./portfolio_analytics.sh "$(NORMALIZED)" "$(MATCHES)" .
	jq -e . "$(MONTHLY)" >/dev/null
	jq -e . "$(YEARLY)" >/dev/null
	jq -e . "$(CAPITAL)" >/dev/null
	jq -e . "$(TRADE_STATS)" >/dev/null

$(RISK): $(NORMALIZED) $(MATCHES) $(DAILY) $(MONTHLY) $(SYMBOLS) risk_behavior.sh
	source ./risk_behavior.sh "$(NORMALIZED)" "$(MATCHES)" .
	jq -e . "$(RISK)" >/dev/null

$(OPEN_ANALYTICS): $(NORMALIZED) $(OPEN_LOTS) open_lot_analytics.sh
	source ./open_lot_analytics.sh "$(NORMALIZED)" "$(OPEN_LOTS)" .
	jq -e . "$(OPEN_ANALYTICS)" >/dev/null

$(EFFICIENCY) $(EFFICIENCY_FRAGMENTS): $(MATCHES) trade_efficiency.sh
	source ./trade_efficiency.sh "$(MATCHES)" .
	jq -e . "$(EFFICIENCY)" >/dev/null
	jq -e . "$(EFFICIENCY_FRAGMENTS)" >/dev/null

$(EFFICIENCY_MONTHLY) $(EFFICIENCY_YEARLY): $(EFFICIENCY_FRAGMENTS) trade_efficiency_time.sh
	source ./trade_efficiency_time.sh "$(EFFICIENCY_FRAGMENTS)" .
	jq -e . "$(EFFICIENCY_MONTHLY)" >/dev/null
	jq -e . "$(EFFICIENCY_YEARLY)" >/dev/null

$(CAPITAL_VELOCITY) $(CAPITAL_VELOCITY_YEARLY): $(MATCHES) $(CAPITAL) capital_velocity.sh
	source ./capital_velocity.sh "$(MATCHES)" "$(CAPITAL)" .
	jq -e . "$(CAPITAL_VELOCITY)" >/dev/null
	jq -e . "$(CAPITAL_VELOCITY_YEARLY)" >/dev/null

$(EXPOSURE) $(EXPOSURE_SYMBOLS): $(EFFICIENCY_FRAGMENTS) $(OPEN_ANALYTICS) exposure_concentration.sh
	source ./exposure_concentration.sh "$(EFFICIENCY_FRAGMENTS)" "$(OPEN_ANALYTICS)" .
	jq -e . "$(EXPOSURE)" >/dev/null
	jq -e . "$(EXPOSURE_SYMBOLS)" >/dev/null

$(STRATEGY_BEHAVIOR): $(SUMMARY) $(RISK) $(EFFICIENCY) $(CAPITAL_VELOCITY) $(OPEN_ANALYTICS) $(EXPOSURE) strategy_behavior.sh
	source ./strategy_behavior.sh .
	jq -e . "$(STRATEGY_BEHAVIOR)" >/dev/null

$(DASHBOARD_DATA): $(SUMMARY) $(EFFICIENCY_MONTHLY) $(EFFICIENCY_YEARLY) $(EXPOSURE) $(RISK) $(OPEN_ANALYTICS) $(CAPITAL_VELOCITY) $(CAPITAL_VELOCITY_YEARLY) $(STRATEGY_BEHAVIOR) $(EFFICIENCY) dashboard_data.sh
	source ./dashboard_data.sh .

check: all
	@printf 'CSV records: '
	@awk 'END {print NR-1}' "$(CSV)"
	@printf 'Raw JSONL records: '
	@wc -l < "$(JSONL)"
	@printf 'Normalized records: '
	@wc -l < "$(NORMALIZED)"
	@printf 'FIFO match rows: '
	@wc -l < "$(MATCHES)"
	@printf 'Open lots: '
	@wc -l < "$(OPEN_LOTS)"
	@printf 'JSON validation: '
	@jq -e . "$(JSONL)" >/dev/null
	@jq -e . "$(NORMALIZED)" >/dev/null
	@jq -e . "$(MATCHES)" >/dev/null
	@jq -e . "$(OPEN_LOTS)" >/dev/null
	@jq -e . "$(SUMMARY)" >/dev/null
	@jq -e . "$(RISK)" >/dev/null
	@jq -e . "$(OPEN_ANALYTICS)" >/dev/null
	@jq -e . "$(EFFICIENCY)" >/dev/null
	@jq -e . "$(CAPITAL_VELOCITY)" >/dev/null
	@jq -e . "$(EXPOSURE)" >/dev/null
	@jq -e . "$(STRATEGY_BEHAVIOR)" >/dev/null
	@printf 'Dashboard data JSON payload: '
	@sed '$$d' "$(DASHBOARD_DATA)" | sed '1s/^const DASHBOARD_DATA = //' | sed '$$s/;$$//' | jq -e . >/dev/null
	@echo 'OK'

clean:
	rm -f "$(JSONL)" "$(NORMALIZED)" "$(MATCHES)" "$(OPEN_LOTS)" "$(WARNINGS)" \
		"$(DAILY)" "$(ROLLING)" "$(SYMBOLS)" "$(SUMMARY)" \
		"$(MONTHLY)" "$(YEARLY)" "$(CAPITAL)" "$(TRADE_STATS)" \
		"$(RISK)" "$(OPEN_ANALYTICS)" \
		"$(EFFICIENCY)" "$(EFFICIENCY_FRAGMENTS)" "$(EFFICIENCY_MONTHLY)" "$(EFFICIENCY_YEARLY)" \
		"$(CAPITAL_VELOCITY)" "$(CAPITAL_VELOCITY_YEARLY)" \
		"$(EXPOSURE)" "$(EXPOSURE_SYMBOLS)" "$(STRATEGY_BEHAVIOR)" "$(DASHBOARD_DATA)"

JSONL_INPUT ?=
JSON_OUTPUT ?=
jsonl-to-json:
	@if [[ -z "$(JSONL_INPUT)" ]]; then \
		echo 'Usage: make jsonl-to-json JSONL_INPUT=file.jsonl [JSON_OUTPUT=file.json]' >&2; \
		exit 1; \
	fi
	@if [[ -n "$(JSON_OUTPUT)" ]]; then \
		source ./jsonl_to_json.sh "$(JSONL_INPUT)" "$(JSON_OUTPUT)"; \
	else \
		source ./jsonl_to_json.sh "$(JSONL_INPUT)"; \
	fi
