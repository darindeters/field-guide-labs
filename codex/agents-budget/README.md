# agents-budget: how much of your AGENTS.md does Codex load?

Codex reads your project's `AGENTS.md` files into one shared byte budget, `project_doc_max_bytes`, which defaults to 32 KiB. When the chain of files from your git root down to the folder you start in goes over that budget, Codex cuts the file that crosses the line and never loads anything after it. The only sign is a warning in the Codex log.

`agents-budget.sh` walks the same chain Codex walks and shows you exactly what loads.

```
$ agents-budget.sh registry
chain for ./registry  (budget 32768 bytes)
     22734  AGENTS.md                                                 ok
     22465  registry/AGENTS.md                                        CUT: first 10034 bytes load, last 12431 never do
     45199  total, 12431 over budget
```

## Install

It's one bash script with no dependencies beyond `git`. Copy it into your repo, or run it straight from a checkout:

```bash
curl -fsSL https://raw.githubusercontent.com/darindeters/field-guide-labs/main/codex/agents-budget/agents-budget.sh -o agents-budget.sh
chmod +x agents-budget.sh
```

Read it before you run it. It's about 130 lines.

## Use

```bash
./agents-budget.sh                 # the chain for the folder you're in
./agents-budget.sh services/api    # the chain for one folder
./agents-budget.sh --all           # every folder that has an instruction file
```

If you changed Codex's settings, tell the script:

```bash
CODEX_BUDGET=65536 ./agents-budget.sh --all
CODEX_FALLBACKS="TEAM_GUIDE.md .agents.md" ./agents-budget.sh --all
```

Exit code `1` means some instructions never load, so `--all` works as a CI gate. See [examples/github-actions.yml](examples/github-actions.yml).

## What it checks, and why

Every rule below comes from the Codex source, `codex-rs/core/src/agents_md.rs` in [openai/codex](https://github.com/openai/codex), checked on 2026-10-16 (last change to that file: 2026-09-16). Where the docs say something different, the source wins.

1. **One budget for the whole chain.** The budget is shared by every project file from the git root down, spent root first. The [AGENTS.md guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md) says it's combined, but the [config docs](https://learn.chatgpt.com/docs/config-file/config-advanced#project-instructions-discovery) describe it as per file. The source matches the guide.
2. **Cut partway through, not dropped whole.** The file that crosses the budget is truncated at the remaining byte count, so its end is what disappears. Put the rules that matter most at the top of each file.
3. **Files after the cut never load.** Once the budget is spent, deeper files are skipped.
4. **One file per folder, first one that exists.** `AGENTS.override.md`, then `AGENTS.md`, then your fallback names. The script reports the file Codex picks.
5. **An empty override hides the folder.** Codex picks the first file that *exists*, then skips it if it's empty or whitespace. An empty `AGENTS.override.md` therefore hides the real `AGENTS.md` beside it, and that folder contributes nothing. The script flags this as `EMPTY ... hides`.
6. **Your global file is separate.** `~/.codex/AGENTS.md` (or `$CODEX_HOME`) is loaded as user instructions and does not draw on the project budget, so the script ignores it.

## What it doesn't check

- **Untrusted projects.** If a project is saved with `trust_level = "untrusted"`, Codex loads no project `AGENTS.md` at all, only your global file. The script can't see your trust settings. Check `~/.codex/config.toml`.
- **Custom `project_root_markers`.** The script uses the git root. If you changed the markers Codex uses to find the project root, results may differ.
- **Byte-exact edge cases.** Codex trims Unicode whitespace when it decides a file is empty. The script uses POSIX whitespace. This only matters for files that contain nothing but unusual whitespace.

## Data from the video

[data/public-repos-2026-10-16.json](data/public-repos-2026-10-16.json) has the chain measurements for the 12 public repos measured for Codex Field Guide #1, taken from each repo's default branch on 2026-10-16 with the default 32 KiB budget. Those repos may write `AGENTS.md` for several coding agents, and their maintainers may raise the limit in their own config. The numbers describe Codex's default behavior, not a mistake by the projects. GitHub truncated the file listing for elastic/kibana, so its result (no folder over budget) is a lower bound.

## Test

```bash
./test.sh
```

It builds throwaway git repos with known file sizes and checks every rule above. CI runs it on Linux and macOS.
