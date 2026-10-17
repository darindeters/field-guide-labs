#!/usr/bin/env bash
# Self-test for retrieve.py: the ACL runs before ranking, so a role never
# gets a doc it cannot see, and the prompt-only mode shows the leak.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
run() { python3 "$here/retrieve.py" "$@"; }
fail() { echo "FAIL: $1"; echo "$out"; exit 1; }

for q in "q3 numbers" "payroll" "vendor spend" "q3"; do
  out="$(run --role engineer "$q")"
  echo "$out" | grep -q "\[finance\]" && fail "engineer got a finance doc for '$q'"
  echo "$out" | grep -q "should not see, in context: 0" || fail "engineer leak count for '$q'"
  echo "ok: engineer, '$q' -> no finance docs"
done

out="$(run --role finance "q3 numbers")"
echo "$out" | grep -q "Q3 payroll (fictional)" || fail "finance role missing payroll doc"
echo "$out" | grep -q "removed 1 before ranking" || fail "finance role should lose only the engineer doc"
echo "ok: finance, 'q3 numbers' -> payroll doc present"

out="$(run --role finance "rotation")"
echo "$out" | grep -q "On-call rotation" && fail "finance got an engineer-only doc"
echo "ok: finance, 'rotation' -> no engineer-only doc"

out="$(run --no-acl --role engineer "q3 numbers")"
echo "$out" | grep -q "\[finance\] Q3 payroll (fictional)" || fail "no-acl mode should show the leak"
echo "$out" | grep -q "should not see, in context: 2" || fail "no-acl leak count"
echo "$out" | grep -q "system prompt:" || fail "no-acl mode should print the prompt rule"
echo "ok: no-acl, engineer -> 2 finance docs in context, one prompt line in the way"

out="$(run --role engineer "q3 numbers")"
[ "$(echo "$out" | awk '{ if (length > 80) n++ } END { print n+0 }')" = 0 ] || fail "line over 80 columns"
echo "PASS"
