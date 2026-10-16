# Reproduce Fail File #1: Codex reading half the rules

This is the exact test from the video. It takes about 10 minutes and a few messages of Codex usage. Results were recorded on 2026-10-16 with Codex 0.163.0. See [SOURCES.md](SOURCES.md#4-the-live-run-fail-file-1).

## 1. Setup

Use a current Codex. The behavior below was checked on 0.163.0.
```bash
npm install -g @openai/codex@latest && codex --version
```

Download only Airflow's instruction files (a few MB):
```bash
mkdir -p ~/labs && cd ~/labs && git clone --depth 1 --filter=blob:none --sparse https://github.com/apache/airflow.git
```
```bash
cd ~/labs/airflow && git sparse-checkout set --no-cone '**/AGENTS.md' '**/AGENTS.override.md'
```

## 2. Run with the default budget

```bash
cd ~/labs/airflow/registry && codex -c log_dir=./.codex-log
```
- If Codex asks whether to trust the folder, **trust it.** An untrusted folder loads no project AGENTS.md at all.
- If Codex asks to read or run anything during the test, **decline.** You're testing what's in its instructions.

Ask:
1. `Without opening any files, list every section heading in your current project instructions.`
2. `Without opening any files: what do your instructions say about the registry's deployment architecture?`

**On 2026-10-16:**
- The heading list ended at "Common Issues".
- Question 2 got: "The provided project instructions don't specify the registry's deployment architecture or hosting setup."

## 3. Find the evidence

Quit Codex, then:
```bash
grep -i "exceeds remaining budget" .codex-log/codex-tui.log
```
Expect a line ending in `remaining_bytes=10034`. If Airflow has changed its files since 2026-10-16, the number will differ.

```bash
/path/to/agents-budget.sh
```
Expect `CUT: first 10034 bytes load, last 12431 never do`.

## 4. Raise the budget and ask again

```bash
codex -c project_doc_max_bytes=65536 -c log_dir=./.codex-log2
```
Ask question 2 again.

**On 2026-10-16:** the answer described the S3 build, CloudFront serving, the path prefix, and the separate site changes. It ended with "I opened no files."

## Notes

- Passing `-c` overrides makes Codex show a startup warning about embedded mode. It's unrelated to the cut. To avoid it, set `project_doc_max_bytes = 65536` in `~/.codex/config.toml` instead.
- If Codex fails with "model is not supported when using Codex with a ChatGPT account", your `~/.codex/config.toml` names a model your plan can't use. Run `/model` in Codex and pick one. (That was the first take in the video.)
- The better long-term fix: keep the root AGENTS.md short, move team rules into their folders, and put the rules that matter most at the top of each file.
