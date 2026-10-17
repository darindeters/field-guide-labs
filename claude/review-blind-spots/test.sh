#!/usr/bin/env bash
# Self-test: the demo repo reproduces the cross-file bug without any AI call.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
bash "$here/setup.sh" "$tmp/billing-service" >/dev/null
cd "$tmp/billing-service"

changed="$(git diff --staged --name-only)"
[ "$changed" = "billing/money.py" ] || { echo "FAIL: diff should touch only billing/money.py, got: $changed"; exit 1; }
echo "ok: the diff touches only billing/money.py"

grep -q "parse_amount" billing/invoice.py || { echo "FAIL: caller missing"; exit 1; }
echo "ok: billing/invoice.py calls parse_amount and is not in the diff"

after="$(python3 invoice_demo.py | tail -1)"
[ "$after" = "1845.0" ] || { echo "FAIL: expected 1845.0 with the change, got $after"; exit 1; }
git stash -q
before="$(python3 invoice_demo.py | tail -1)"
git stash pop -q
[ "$before" = "20.5" ] || { echo "FAIL: expected 20.5 before the change, got $before"; exit 1; }
echo "ok: a \$20.50 invoice totals $before before the change and $after after it"
echo "PASS"
