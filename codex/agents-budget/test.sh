#!/usr/bin/env bash
# Self-test for agents-budget.sh: builds throwaway repos with known file sizes
# and checks the report against what the Codex loader would do.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
TOOL="$HERE/agents-budget.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fails=0

fill() { mkdir -p "$(dirname "$1")"; head -c "$2" /dev/zero | tr '\0' 'x' > "$1"; }
repo() { rm -rf "$WORK/r"; mkdir -p "$WORK/r"; git -C "$WORK/r" init -q; }
expect() { # name, expected exit, pattern, command...
  local name="$1" want="$2" pat="$3"; shift 3
  local out code
  out="$("$@" 2>&1)"; code=$?
  if [ "$code" -ne "$want" ] || ! printf '%s' "$out" | grep -q -- "$pat"; then
    echo "FAIL: $name (exit $code, wanted $want, pattern '$pat')"; printf '%s\n' "$out" | sed 's/^/    /'; fails=$((fails + 1))
  else
    echo "ok:   $name"
  fi
}

# 1. Same sizes as Apache Airflow's root and registry/ files (Oct 2026).
repo; fill "$WORK/r/AGENTS.md" 22734; fill "$WORK/r/registry/AGENTS.md" 22465
expect "cut lands mid-file" 1 "CUT: first 10034 bytes load, last 12431 never do" "$TOOL" "$WORK/r/registry"
expect "root alone fits" 0 "22734  total, 0 over budget" "$TOOL" "$WORK/r"
expect "raised budget fits" 0 "total, 0 over budget" env CODEX_BUDGET=65536 "$TOOL" "$WORK/r/registry"

# 2. Budget spent before a deeper file: that file never loads.
repo; fill "$WORK/r/AGENTS.md" 32768; fill "$WORK/r/a/AGENTS.md" 100
expect "file after the cap is skipped" 1 "SKIPPED: budget already spent" "$TOOL" "$WORK/r/a"

# 3. An empty override still wins, so the AGENTS.md beside it never loads.
repo; fill "$WORK/r/AGENTS.md" 100; mkdir -p "$WORK/r/svc"; printf '  \n' > "$WORK/r/svc/AGENTS.override.md"; fill "$WORK/r/svc/AGENTS.md" 500
expect "empty override hides AGENTS.md" 1 "EMPTY: skipped, and it hides AGENTS.md" "$TOOL" "$WORK/r/svc"

# 4. A lone empty file is skipped and is not an error.
repo; fill "$WORK/r/AGENTS.md" 100; mkdir -p "$WORK/r/b"; : > "$WORK/r/b/AGENTS.md"
expect "lone empty file is fine" 0 "empty: skipped" "$TOOL" "$WORK/r/b"

# 5. A non-empty override shadows AGENTS.md in the same folder.
repo; fill "$WORK/r/c/AGENTS.override.md" 50; fill "$WORK/r/c/AGENTS.md" 40000
expect "override wins" 0 "c/AGENTS.override.md" "$TOOL" "$WORK/r/c"

# 6. Fallback names only count when you list them.
repo; fill "$WORK/r/TEAM_GUIDE.md" 40000
expect "unlisted fallback ignored" 0 "0  total" "$TOOL" "$WORK/r"
expect "listed fallback counted" 1 "TEAM_GUIDE.md" env CODEX_FALLBACKS="TEAM_GUIDE.md" "$TOOL" "$WORK/r"

# 7. Folder names with spaces, and --all across the repo.
repo; fill "$WORK/r/AGENTS.md" 30000; fill "$WORK/r/team one/AGENTS.md" 5000; fill "$WORK/r/team two/AGENTS.md" 100
expect "spaces in folder names" 1 "team one/AGENTS.md" "$TOOL" "$WORK/r/team one"
expect "--all reports only the broken chain" 1 "team one" bash -c "cd '$WORK/r' && '$TOOL' --all"
expect "--all leaves out passing chains" 1 "^0$" bash -c "cd '$WORK/r' && '$TOOL' --all | grep -c 'team two'"
repo; fill "$WORK/r/AGENTS.md" 100; fill "$WORK/r/x/AGENTS.md" 100
expect "--all passes a healthy repo" 0 "all 2 instruction chains load in full" bash -c "cd '$WORK/r' && '$TOOL' --all"

# 8. Usage errors.
mkdir -p "$WORK/nogit"
expect "outside git is a usage error" 2 "not inside a git repo" "$TOOL" "$WORK/nogit"
expect "bad budget is a usage error" 2 "whole number" env CODEX_BUDGET=32k "$TOOL" "$WORK/r"

echo
if [ "$fails" -eq 0 ]; then echo "all tests passed"; else echo "$fails test(s) failed"; exit 1; fi
