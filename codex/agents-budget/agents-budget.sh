#!/usr/bin/env bash
# agents-budget.sh: how much of your AGENTS.md chain does Codex actually load?
#
# Mirrors the Codex loader (openai/codex, codex-rs/core/src/agents_md.rs,
# checked 2026-10-16). Codex walks from the git root down to the folder you
# start in and takes the first file that exists in each folder:
# AGENTS.override.md, then AGENTS.md, then any fallback names. An empty or
# whitespace-only file is still the one it picks, and then it is skipped, so
# an empty override hides the AGENTS.md beside it. Codex spends one shared
# byte budget (project_doc_max_bytes, default 32 KiB) from the root first.
# The file that crosses the budget is cut partway through, and files after
# it never load. Your global ~/.codex file is loaded separately and does not
# count against the budget.
#
# Usage:
#   agents-budget.sh [folder]   check one folder's chain (default: current folder)
#   agents-budget.sh --all      check every folder that has an instruction file
#
# Environment:
#   CODEX_BUDGET=65536                    if you raised project_doc_max_bytes
#   CODEX_FALLBACKS="TEAM_GUIDE.md .agents.md"
#                                         your project_doc_fallback_filenames
#
# Exit codes: 0 everything loads, 1 some instructions never load (cut,
# skipped, or hidden by an empty file), 2 usage error.

set -u

BUDGET="${CODEX_BUDGET:-32768}"
read -r -a NAMES <<< "AGENTS.override.md AGENTS.md ${CODEX_FALLBACKS:-}"

die() { echo "agents-budget: $*" >&2; exit 2; }

case "$BUDGET" in ''|*[!0-9]*) die "CODEX_BUDGET must be a whole number of bytes" ;; esac

# The instruction file Codex picks in a folder: the first one that exists,
# empty or not.
pick() {
  local n
  for n in "${NAMES[@]}"; do
    if [ -f "$1/$n" ]; then printf '%s\n' "$1/$n"; return; fi
  done
}

# Other instruction files in the same folder that the picked one shadows.
shadowed() {
  local n seen=0 out=""
  for n in "${NAMES[@]}"; do
    [ -f "$1/$n" ] || continue
    if [ "$seen" -eq 1 ]; then out="$out $n"; fi
    seen=1
  done
  printf '%s' "${out# }"
}

# Print one folder's chain. Returns 1 if the chain goes over the budget.
chain() {
  local target root rel d f size left hidden acc=0 over=0 part
  local -a parts=()
  target="$(cd "$1" 2>/dev/null && pwd -P)" || die "no such folder: $1"
  root="$(cd "$target" && git rev-parse --show-toplevel 2>/dev/null)" || die "$1 is not inside a git repo"
  root="$(cd "$root" && pwd -P)"
  rel="${target#"$root"}"
  rel="${rel#/}"
  [ -n "$rel" ] && IFS='/' read -r -a parts <<< "$rel"

  echo "chain for ./${rel}  (budget ${BUDGET} bytes)"
  d="$root"
  for part in "" "${parts[@]+"${parts[@]}"}"; do
    [ -n "$part" ] && d="$d/$part"
    f="$(pick "$d")"
    [ -z "$f" ] && continue
    size=$(wc -c < "$f" | tr -d ' ')
    left=$((BUDGET - acc))
    if ! grep -q '[^[:space:]]' "$f"; then
      hidden="$(shadowed "$d")"
      if [ -n "$hidden" ]; then
        printf '  %8s  %-56s  EMPTY: skipped, and it hides %s\n' "$size" "${f#"$root"/}" "$hidden"
        over=1
      else
        printf '  %8s  %-56s  empty: skipped\n' "$size" "${f#"$root"/}"
      fi
      continue
    elif [ "$left" -le 0 ]; then
      printf '  %8s  %-56s  SKIPPED: budget already spent\n' "$size" "${f#"$root"/}"
      over=1
    elif [ "$size" -gt "$left" ]; then
      printf '  %8s  %-56s  CUT: first %s bytes load, last %s never do\n' "$size" "${f#"$root"/}" "$left" $((size - left))
      over=1
    else
      printf '  %8s  %-56s  ok\n' "$size" "${f#"$root"/}"
    fi
    acc=$((acc + size))
  done
  printf '  %8s  total, %s over budget\n\n' "$acc" $(( acc > BUDGET ? acc - BUDGET : 0 ))
  return "$over"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

if [ "${1:-}" != "--all" ]; then
  chain "${1:-.}"
  exit $?
fi

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repo"
find_args=()
for n in "${NAMES[@]}"; do
  [ ${#find_args[@]} -gt 0 ] && find_args+=(-o)
  find_args+=(-name "$n")
done

status=0
checked=0
report="$(mktemp)"
trap 'rm -f "$report"' EXIT
while IFS= read -r d; do
  checked=$((checked + 1))
  if ! chain "$root/$d" > "$report"; then
    cat "$report"
    status=1
  fi
done < <(cd "$root" && find . \( -name .git -o -name node_modules \) -prune -o -type f \( "${find_args[@]}" \) -print \
         | sed 's|/[^/]*$||' | sort -u)

if [ "$status" -eq 0 ]; then
  echo "all ${checked} instruction chains load in full (budget ${BUDGET} bytes)"
fi
exit "$status"
