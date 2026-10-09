#!/usr/bin/env bash
#
# jsonl_to_json.sh
#
# Convert a JSONL/NDJSON stream into one valid JSON array.
#
# Usage:
#   source ./jsonl_to_json.sh input.jsonl [output.json]
#
# If output.json is omitted, the input basename is used with a .json extension.
# The script is intentionally non-executable and is meant to be sourced.
#

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: source ./jsonl_to_json.sh input.jsonl [output.json]" >&2
    return 1 2>/dev/null || exit 1
fi

input=$1

if [[ ! -f "$input" ]]; then
    echo "ERROR: input file not found: $input" >&2
    return 1 2>/dev/null || exit 1
fi

if [[ $# -eq 2 ]]; then
    output=$2
else
    output=${input%.jsonl}.json
fi

if [[ "$output" == "$input" ]]; then
    echo "ERROR: output would overwrite input JSONL file" >&2
    return 1 2>/dev/null || exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required" >&2
    return 1 2>/dev/null || exit 1
fi

if ! jq -s '.' "$input" > "$output"; then
    echo "ERROR: jq could not parse JSONL input: $input" >&2
    rm -f "$output"
    return 1 2>/dev/null || exit 1
fi

echo "Created: $output"
