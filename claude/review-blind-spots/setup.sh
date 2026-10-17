#!/usr/bin/env bash
# Builds the demo repo from the Field Guide video: a tiny billing service
# with one staged change that switches parse_amount from dollars to cents.
# The caller in billing/invoice.py is NOT in the diff, and it breaks.
#
# Usage: ./setup.sh [target-dir]   (default: ./billing-service)
set -euo pipefail
lab="$(cd "$(dirname "$0")" && pwd)"
dir="${1:-billing-service}"
if [ -e "$dir" ]; then echo "error: $dir already exists" >&2; exit 1; fi
mkdir -p "$dir/billing" && cd "$dir"
git init -q
git config user.name "Field Guide Labs"
git config user.email "labs@example.com"

cat > billing/__init__.py <<'EOF'
EOF
cat > billing/money.py <<'EOF'
def parse_amount(text: str) -> float:
    """Parse a price like "12.50" into dollars."""
    return float(text.strip())
EOF
cat > billing/invoice.py <<'EOF'
from billing.money import parse_amount

BULK_DISCOUNT_THRESHOLD = 1000  # dollars


def invoice_total(lines: list[str]) -> float:
    total = sum(map(parse_amount, lines))
    if total > BULK_DISCOUNT_THRESHOLD:
        total *= 0.9
    return round(total, 2)
EOF
cat > invoice_demo.py <<'EOF'
from billing.invoice import invoice_total

print("Invoice for two items, $12.50 + $8.00:")
print(invoice_total(["12.50", "8.00"]))
EOF
cp -R "$lab/repo-files/." .
git add -A && git commit -qm "billing: invoice totals"

# The pull request: dollars -> integer cents. Only money.py changes.
cat > billing/money.py <<'EOF'
def parse_amount(text: str) -> int:
    """Parse a price like "12.50" into integer cents."""
    return round(float(text.strip()) * 100)
EOF
git add billing/money.py
echo "Ready: $(pwd)"
echo "The change is staged. Try: git diff --staged && python3 invoice_demo.py"
