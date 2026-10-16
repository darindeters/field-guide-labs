#!/usr/bin/env bash
# Measure the AGENTS.md chains in 12 public repos with agents-budget.sh.
# Downloads only each repo's instruction files (a few MB total) into a temp
# folder, runs the check, and prints a one-line verdict per repo.
TOOL="$(cd "$(dirname "$0")/.." && pwd)/agents-budget.sh"
REPOS="apache/airflow grafana/grafana n8n-io/n8n pydantic/pydantic-ai vercel/next.js langchain-ai/langchain
openai/openai-agents-python openai/openai-agents-js elastic/kibana supabase/supabase vercel/ai cloudflare/workers-sdk"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
over=0
for r in $REPOS; do
  d="$WORK/${r//\//_}"
  git clone -q --depth 1 --filter=blob:none --sparse "https://github.com/$r.git" "$d" 2>/dev/null || { echo "$r: clone failed"; continue; }
  (cd "$d" && git sparse-checkout set --no-cone '**/AGENTS.md' '**/AGENTS.override.md' >/dev/null 2>&1)
  out="$(cd "$d" && "$TOOL" --all)"; code=$?
  if [ "$code" -eq 1 ]; then
    over=$((over + 1))
    worst="$(printf '%s\n' "$out" | grep -E 'CUT|SKIPPED|EMPTY' | head -1 | sed -E 's/^ +//')"
    echo "OVER  $r  ->  $worst"
  else
    echo "ok    $r"
  fi
done
echo; echo "$over of 12 repos have instructions Codex would cut off on default settings ($(date +%F))"
