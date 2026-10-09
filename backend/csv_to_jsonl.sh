#!/usr/bin/env bash
set -euo pipefail

INPUT=${1:?usage: csv_to_jsonl.sh INPUT.csv [OUTPUT.jsonl]}
OUTPUT=${2:-${INPUT%.csv}.jsonl}

mkdir -p "$(dirname "$OUTPUT")"

awk '
function csv_parse(line,    i,c,nextc,inquote,field,n) {
    n = 0
    field = ""
    inquote = 0
    for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        nextc = (i < length(line) ? substr(line, i + 1, 1) : "")

        if (inquote) {
            if (c == "\"") {
                if (nextc == "\"") {
                    field = field "\""
                    i++
                } else {
                    inquote = 0
                }
            } else {
                field = field c
            }
        } else if (c == "\"") {
            inquote = 1
        } else if (c == ",") {
            fields[++n] = field
            field = ""
        } else {
            field = field c
        }
    }
    fields[++n] = field
    return n
}

function json_escape(s,    t) {
    t = s
    gsub(/\\/, "\\\\", t)
    gsub(/"/, "\\\"", t)
    gsub(/\r/, "\\r", t)
    gsub(/\n/, "\\n", t)
    gsub(/\t/, "\\t", t)
    return t
}

function json_quote(s) {
    return "\"" json_escape(s) "\""
}

function money_number(s,    t) {
    t = s
    gsub(/\$/, "", t)
    gsub(/,/, "", t)
    if (t == "" || t == "-") return "null"
    return t + 0
}

function number_or_null(s) {
    if (s == "") return "null"
    return s + 0
}

function emit_record(    i,comma) {
    printf "{\"source_row\":%d", NR
    comma = ","
    for (i = 1; i <= field_count; i++) {
        printf "%s%s:%s", comma, json_quote(headers[i]), json_quote(fields[i])
        comma = ","
    }
    printf ",\"amount_value\":%s", money_number(fields[5])
    printf ",\"fee_value\":%s", money_number(fields[6])
    printf ",\"net_amount_value\":%s", money_number(fields[7])
    printf ",\"asset_price_value\":%s", money_number(fields[9])
    printf ",\"asset_amount_value\":%s", number_or_null(fields[10])
    printf "}\n"
}

NR == 1 {
    field_count = csv_parse($0)
    for (i = 1; i <= field_count; i++) {
        headers[i] = tolower(fields[i])
        gsub(/[ -]/, "_", headers[i])
    }
    next
}

{
    field_count = csv_parse($0)
    emit_record()
}
' "$INPUT" > "$OUTPUT"

printf 'Wrote %s\n' "$OUTPUT"
