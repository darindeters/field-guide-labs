# review-blind-spots

Companion lab for **Claude Field Guide #9: Why Your AI Code Reviewer Misses Real Bugs**.

The video makes two claims, and this lab lets you test both on your own machine:

1. **A confidence gate hides real bugs.** If your review prompt says "only report what you're highly confident about," a reviewer that suspects a bug can still return a clean verdict.
2. **A diff-only reviewer can't see cross-file bugs.** When a change breaks a caller in a file the diff doesn't include, the reviewer has to search and read the repo to find it.

## The demo repo

`setup.sh` builds a tiny billing service with one staged change. `parse_amount` in `billing/money.py` now returns integer cents instead of dollars. Its caller, `invoice_total` in `billing/invoice.py`, isn't in the diff and still treats the number as dollars.

```bash
./setup.sh            # creates ./billing-service with the change staged
cd billing-service
git diff --staged     # only billing/money.py
python3 invoice_demo.py
```

Before the change, a $12.50 + $8.00 invoice totals `20.5`. After it, the total is `1845.0`: the sum is in cents, and the $1,000 bulk discount now kicks in at $10.

## Run 1: the confidence gate (diff only, no tools)

```bash
git diff --staged | claude -p "Review this diff. Only report bugs you are highly confident are real. If unsure, say: No high-confidence issues." --tools ""
```

Recorded output, Oct 17, 2026 (Claude Code 2.1.296):

> **No high-confidence issues.**
> ...
> One thing worth checking yourself: the return type changed from float dollars to int cents. Any caller that still treats the result as dollars will now be off by a factor of 100. That is a real risk, but I could not confirm it from the diff alone.

The reviewer suspected the bug, and the verdict still came back clean. If your pipeline only posts findings, that note never reaches the pull request.

## Run 2: let the reviewer search and read

```bash
git diff --staged | claude -p "Review this diff. Grep for every caller of what changed and read those files. At most four issues, one short line each: file:line, problem." --tools "Read,Grep,Glob"
```

Recorded output from the same session. The first finding:

> `billing/invoice.py:8` - `total` is now cents but `BULK_DISCOUNT_THRESHOLD` is still 1000 dollars, so the 10% discount fires at $10.01 instead of $1000.

## Notes

- Model output varies from run to run. Your wording will differ. The pattern should hold: the gated, diff-only run hedges, and the run with Read/Grep/Glob cites the caller.
- `--tools ""` removes every tool, so the reviewer sees only the diff. `--tools "Read,Grep,Glob"` gives it read-only access to the repo. Neither run can edit files.
- Put the prompt before `--tools`. The flag accepts several values and swallows anything after it.
- `test.sh` checks the repo itself (the diff, the caller, and both totals) and needs no API key. It runs in CI.

Sources and the exact doc passages: [SOURCES.md](SOURCES.md)
