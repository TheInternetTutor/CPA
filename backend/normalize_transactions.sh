#!/usr/bin/env bash
set -euo pipefail

INPUT=${1:?usage: normalize_transactions.sh INPUT.jsonl [OUTPUT.jsonl]}
OUTPUT=${2:-${INPUT%.jsonl}.normalized.jsonl}

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }

jq -c '
  . as $r
  | if .status != "COMPLETE" then
      .analysis_class = (
        if ((.transaction_type == "Stock Buy") or (.asset_type != "" and ((.notes // "")|test("Sale"; "i"))))
        then "STOCK_ORDER_NOT_COMPLETED"
        else "NON_COMPLETED_TRANSACTION"
        end
      )
      | .trading_side = null
      | .external_cash_flow = 0
      | .trading_cash_flow = 0
    elif .transaction_type == "Stock Buy" then
      .analysis_class = "STOCK_BUY_COMPLETED"
      | .trading_side = "BUY"
      | .external_cash_flow = 0
      | .trading_cash_flow = .amount_value
      | .execution_price = ((.amount_value|abs) / .asset_amount_value)
    elif (.transaction_type == "" and .asset_type != "" and (.notes|test("Sale"; "i"))) then
      .analysis_class = "STOCK_SELL_COMPLETED"
      | .trading_side = "SELL"
      | .external_cash_flow = 0
      | .trading_cash_flow = .amount_value
      | .execution_price = ((.amount_value|abs) / .asset_amount_value)
    elif .transaction_type == "Deposits" then
      .analysis_class = "EXTERNAL_DEPOSIT"
      | .trading_side = null
      | .external_cash_flow = .amount_value
      | .trading_cash_flow = 0
    elif .transaction_type == "Withdrawal" then
      .analysis_class = "EXTERNAL_WITHDRAWAL"
      | .trading_side = null
      | .external_cash_flow = .amount_value
      | .trading_cash_flow = 0
    elif .transaction_type == "P2P" and .amount_value > 0 then
      .analysis_class = "EXTERNAL_P2P_INFLOW"
      | .trading_side = null
      | .external_cash_flow = .amount_value
      | .trading_cash_flow = 0
    elif .transaction_type == "P2P" and .amount_value < 0 then
      .analysis_class = "EXTERNAL_P2P_OUTFLOW"
      | .trading_side = null
      | .external_cash_flow = .amount_value
      | .trading_cash_flow = 0
    elif .transaction_type == "Cash Card" then
      .analysis_class = "EXTERNAL_CARD_ACTIVITY"
      | .trading_side = null
      | .external_cash_flow = .amount_value
      | .trading_cash_flow = 0
    elif .transaction_type == "Savings Internal Transfer" then
      .analysis_class = "INTERNAL_SAVINGS_TRANSFER"
      | .trading_side = null
      | .external_cash_flow = 0
      | .trading_cash_flow = 0
    elif .transaction_type == "Stock Dividends" then
      .analysis_class = "DIVIDEND"
      | .trading_side = null
      | .external_cash_flow = 0
      | .trading_cash_flow = 0
    elif .transaction_type == "Savings Interest Payment" then
      .analysis_class = "INTEREST"
      | .trading_side = null
      | .external_cash_flow = 0
      | .trading_cash_flow = 0
    elif .transaction_type == "Loyalty Rewards" or .transaction_type == "Investing" then
      .analysis_class = "OTHER_NON_TRADING_INCOME"
      | .trading_side = null
      | .external_cash_flow = 0
      | .trading_cash_flow = 0
    else
      .analysis_class = "OTHER_IGNORED"
      | .trading_side = null
      | .external_cash_flow = 0
      | .trading_cash_flow = 0
    end
' "$INPUT" > "$OUTPUT"

jq -e . "$OUTPUT" >/dev/null
printf 'Wrote %s\n' "$OUTPUT"
