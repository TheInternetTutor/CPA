#!/usr/bin/env bash
set -euo pipefail

INPUT=${1:?usage: cashapp_csv_to_json.sh INPUT.csv [OUTPUT.json]}
OUTPUT=${2:-${INPUT%.csv}.json}

command -v awk >/dev/null || { echo "error: awk is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }

# Parse quoted CSV safely, normalize numeric currency fields, and emit one JSON object per row.
# jq then collects the JSON Lines into a single JSON array.
awk '
function csvparse(line,    i,c,n,inquote,field) {
    n=0; field=""; inquote=0
    for (i=1; i<=length(line); i++) {
        c=substr(line,i,1)
        if (c=="\"") {
            if (inquote && i<length(line) && substr(line,i+1,1)=="\"") {
                field=field "\""; i++
            } else {
                inquote=!inquote
            }
        } else if (c=="," && !inquote) {
            v[++n]=field; field=""
        } else {
            field=field c
        }
    }
    v[++n]=field
    return n
}
function jesc(s,    t) {
    t=s
    gsub(/\\/,"\\\\",t)
    gsub(/"/,"\\\"",t)
    gsub(/\r/,"\\r",t)
    gsub(/\n/,"\\n",t)
    gsub(/\t/,"\\t",t)
    return t
}
function money(s,    t) {
    t=s
    gsub(/[$,]/,"",t)
    if (t=="") return "null"
    return sprintf("%.10g", t+0)
}
function number(s,    t) {
    t=s
    gsub(/[$,]/,"",t)
    if (t=="") return "null"
    return sprintf("%.10g", t+0)
}
NR==1 {
    n=csvparse($0)
    for (i=1;i<=n;i++) header[i]=v[i]
    next
}
{
    n=csvparse($0)
    printf "{\"source_row\":%d", NR
    for (i=1;i<=n;i++) {
        key=header[i]
        val=v[i]
        if (key=="Amount" || key=="Fee" || key=="Net Amount") {
            printf ",\"%s\":%s", jesc(key), money(val)
        } else if (key=="Asset Price" || key=="Asset Amount") {
            printf ",\"%s\":%s", jesc(key), number(val)
        } else {
            printf ",\"%s\":\"%s\"", jesc(key), jesc(val)
        }
    }
    printf "}\n"
}
' "$INPUT" | jq -s '.' > "$OUTPUT"

printf 'Wrote %s\n' "$OUTPUT" >&2
