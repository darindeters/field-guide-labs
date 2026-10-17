#!/usr/bin/env bash
# Self-test: rules.json is valid and holds the exact rules the video shows.
# The live behavior needs Claude Code and a login, so it is documented in
# README.md rather than run in CI.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
python3 - "$here/rules.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))["permissions"]
assert r["allow"] == ["Bash"], r
assert r["deny"] == ["Bash(curl *)"], r
print("ok: rules.json permits Bash and denies Bash(curl *)")
PY
echo "PASS"
