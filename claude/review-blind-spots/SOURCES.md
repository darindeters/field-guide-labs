# Sources: review-blind-spots

Checked October 17, 2026.

| Claim in the video | Source |
|---|---|
| Managed Code Review runs several agents, then "a verification step checks the candidate findings against the code and filters out false positives" | [Code Review docs, How reviews work](https://code.claude.com/docs/en/code-review) |
| The Code Review check run "doesn't conclude as a failure" | [Code Review docs](https://code.claude.com/docs/en/code-review) |
| "A fresh context improves code review since Claude won't be biased toward code it just wrote" | [Claude Code best practices](https://code.claude.com/docs/en/best-practices) |
| Gated, diff-only review returns "No high-confidence issues" while noting the 100x risk | Run 1 in [README.md](README.md), recorded Oct 17, 2026 with Claude Code 2.1.296 |
| Review with Read/Grep/Glob flags `billing/invoice.py:8` | Run 2 in [README.md](README.md), same recording session |
| A $20.50 invoice totals 1845.0 after the change | `test.sh`, deterministic, runs in CI |
