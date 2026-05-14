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

python3 - "$triage_doc" <<'PY'
import re
import sys
from pathlib import Path

triage_doc = Path(sys.argv[1])
text = triage_doc.read_text(encoding="utf-8")

required_sections = {
    "Addressed in this fork",
    "Partially addressed",
    "Already covered by the final upstream code",
    "Needs Twitch API or product support",
    "Platform, packaging, and distribution follow-up",
    "Administrative",
}

sections = {}
current = None
for line in text.splitlines():
    match = re.match(r"^## (.+)$", line)
    if match:
        current = match.group(1)
        sections[current] = []
    elif current:
        sections[current].append(line)

errors = []
missing_sections = sorted(required_sections - sections.keys())
if missing_sections:
    errors.append("Upstream issue triage is missing sections: " + ", ".join(missing_sections))

def require_issues(section_name, expected_issues):
    body = "\n".join(sections.get(section_name, []))
    for issue in expected_issues:
        if not re.search(rf"(^|[^0-9])#{issue}([^0-9]|$)", body):
            errors.append(f"{section_name} must classify #{issue}")

require_issues(
    "Partially addressed",
    {
        74, 90, 119, 167, 202, 210, 212, 243, 271, 283, 285, 288, 300,
    },
)
require_issues(
    "Already covered by the final upstream code",
    {
        47, 207, 215, 217, 220, 223, 275,
    },
)
require_issues(
    "Needs Twitch API or product support",
    {
        224, 226, 257, 283,
    },
)
require_issues(
    "Platform, packaging, and distribution follow-up",
    {
        34, 42, 216, 219, 235, 239, 261, 267, 276, 277,
    },
)
require_issues("Administrative", {307})

api_body = "\n".join(sections.get("Needs Twitch API or product support", []))
for required_text in (
    "not a supported native HLS playback-token API",
    "does not expose a supported replacement for a native viewer heartbeat",
    "VOD replay-chat export API",
):
    if required_text not in api_body:
        errors.append(f"Needs Twitch API or product support must keep blocker text: {required_text}")

for required_url in (
    "https://github.com/belagrf/orion-revived/issues/1",
    "https://github.com/belagrf/orion-revived/issues/2",
    "https://github.com/belagrf/orion-revived/issues/3",
    "https://dev.twitch.tv/docs/api/videos",
    "https://dev.twitch.tv/docs/api/markers/",
    "https://dev.twitch.tv/docs/drops/",
    "https://dev.twitch.tv/docs/embed/video-and-clips/",
    "https://mpv.io/manual/stable/#low-latency-playback",
):
    if required_url not in text:
        errors.append(f"Upstream issue triage must cite {required_url}")

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)
PY
