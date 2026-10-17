Flag any caller that mixes cents and dollars.

Bad (flag it):
    total = sum(map(parse_amount, lines))   # cents
    if total > 1000:                         # dollars

Good (leave it):
    total_cents = sum(map(parse_amount, lines))
    if total_cents > 1000 * 100:
