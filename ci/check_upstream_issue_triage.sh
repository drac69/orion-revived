#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
triage_doc="$repo_dir/docs/upstream-issue-triage.md"

# Open issues in the archived upstream repository as of the fork audit.
upstream_open_issues=(
    307 306 305 304 302 301 300 298 295 292 288 286 285 284 283 282
    278 277 276 275 274 273 271 270 268 267 265 264 263 261 260 257
    254 243 242 241 240 239 236 235 234 232 226 224 223 220 219 217
    216 215 212 210 207 205 202 199 195 190 187 178 167 142 141 134
    123 119 108 101 90 89 74 47 45 44 42 40 34 26 18
)

if ! rg -q 'had 79 open issues' "$triage_doc"; then
    printf 'Upstream issue triage must document the audited open-issue count.\n' >&2
    exit 1
fi

if (( ${#upstream_open_issues[@]} != 79 )); then
    printf 'The upstream open-issue manifest must contain 79 issues, got %d.\n' "${#upstream_open_issues[@]}" >&2
    exit 1
fi

missing=()
for issue in "${upstream_open_issues[@]}"; do
    if ! rg -q "(^|[^0-9])#${issue}([^0-9]|$)" "$triage_doc"; then
        missing+=("#$issue")
    fi
done

if (( ${#missing[@]} > 0 )); then
    printf 'Upstream issue triage is missing audited issues: %s\n' "${missing[*]}" >&2
    exit 1
fi
