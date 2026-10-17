#!/usr/bin/env bash
# Self-test for log-tool-call.py and settings.json. No Claude login needed.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export TOOL_CALL_LOG="$tmp/log.jsonl"
fail() { echo "FAIL: $1"; cat "$TOOL_CALL_LOG" 2>/dev/null || true; exit 1; }
hook() { python3 "$here/log-tool-call.py"; }

# 1. A Bash call from alice: one line, right fields, nothing on stdout, exit 0.
sample='{"session_id":"abc123","cwd":"/work/proj","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls -la /work/proj","description":"List files"},"tool_use_id":"toolu_01"}'
out="$(echo "$sample" | AGENT_ACTOR=alice@example.com hook)" || fail "hook exited non-zero"
[ -z "$out" ] || fail "hook printed to stdout: $out"
python3 - "$TOOL_CALL_LOG" <<'PY' || fail "first line wrong"
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert len(rows) == 1, rows
r = rows[0]
assert set(r) == {"ts", "actor", "session_id", "tool_name", "input"}, r
assert r["actor"] == "alice@example.com", r
assert r["session_id"] == "abc123" and r["tool_name"] == "Bash", r
assert r["input"] == "command=ls -la .", r
assert r["ts"].endswith("Z"), r
PY
echo "ok: Bash call logged with actor alice@example.com"

# 2. No AGENT_ACTOR: actor falls back to unknown. Paths become relative.
echo '{"session_id":"s2","cwd":"/work/proj","tool_name":"Read","tool_input":{"file_path":"/work/proj/README.md"}}' \
  | env -u AGENT_ACTOR python3 "$here/log-tool-call.py"
tail -n 1 "$TOOL_CALL_LOG" | grep -q '"actor":"unknown"' || fail "fallback actor"
tail -n 1 "$TOOL_CALL_LOG" | grep -q '"input":"file_path=README.md"' || fail "relative path"
echo "ok: missing AGENT_ACTOR -> unknown"

# 3. Garbage on stdin: still exit 0, still no stdout, still a line.
out="$(echo 'not json' | hook)" || fail "garbage input exited non-zero"
[ -z "$out" ] || fail "garbage input printed to stdout"
[ "$(wc -l < "$TOOL_CALL_LOG" | tr -d ' ')" = 3 ] || fail "expected 3 lines"
echo "ok: bad input never blocks the call"

# 4. settings.json registers the hook for every tool.
python3 - "$here/settings.json" "$here" <<'PY' || fail "settings.json"
import json, os, sys
s = json.load(open(sys.argv[1]))
groups = s["hooks"]["PreToolUse"]
assert len(groups) == 1 and groups[0]["matcher"] == "*", groups
h = groups[0]["hooks"][0]
assert h["type"] == "command" and h["command"] == "python3", h
assert h["args"] == ["${CLAUDE_PROJECT_DIR}/log-tool-call.py"], h
assert os.path.isfile(os.path.join(sys.argv[2], "log-tool-call.py"))
PY
echo "ok: settings.json registers PreToolUse for all tools"
echo "PASS"
