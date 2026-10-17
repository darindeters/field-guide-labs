#!/usr/bin/env bash
# Self-test for tool-audit.py against the example roles and edge cases.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
audit() { python3 "$here/tool-audit.py" "$@"; }
expect() { # expect <exit-code> <grep-pattern> <file>
  set +e; out="$(audit "$3")"; code=$?; set -e
  [ "$code" = "$1" ] || { echo "FAIL: $3 exited $code, want $1"; echo "$out"; exit 1; }
  echo "$out" | grep -q "$2" || { echo "FAIL: $3 missing '$2'"; echo "$out"; exit 1; }
  echo "ok: $(basename "$3") -> $2"
}
expect 0 "triangle: OPEN (no outbound tool)" "$here/examples/prod-role.json"
expect 1 "triangle: COMPLETE" "$here/examples/prod-role-after-debug.json"
expect 0 "triangle: OPEN (no outbound tool)" "$here/examples/prod-role-fixed.json"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
echo '{"permissions":{"allow":["Read","mcp__docs__search","Bash"]}}' > "$tmp/bare-bash.json"
expect 1 "outbound         Bash" "$tmp/bare-bash.json"
echo '{"permissions":{"allow":["Read","WebSearch","Bash(curl https://api.example.com/*)"]}}' > "$tmp/curl.json"
expect 1 "Bash(curl https://api.example.com/\*)" "$tmp/curl.json"
echo '{"permissions":{"allow":["Read","Bash(npm test *)"]}}' > "$tmp/no-input.json"
expect 0 "no untrusted input or outbound tool" "$tmp/no-input.json"
echo "PASS"
