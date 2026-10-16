# Sources: Codex Field Guide #1 and Fail File #1

Every claim in both videos, and where it comes from.

- **Codex version:** everything was checked against **Codex 0.163.0** (tag `rust-v0.163.0`, released 2026-10-15). Its `agents_md.rs` is identical to `main` as of 2026-10-16.
- **Docs pages:** read on 2026-10-16.
- **When sources disagree:** the code wins over the docs, and a live run wins over both.

## 1. The budget is 32 KiB, shared by the whole chain

| Claim | Evidence |
|---|---|
| The default `project_doc_max_bytes` is 32 KiB | Code: [`config_toml.rs` L75](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/config/src/config_toml.rs#L75) (`32 * 1024`). Docs: [AGENTS.md guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md) ("32 KiB by default") |
| One budget, shared by every project AGENTS.md file in the chain, spent from the root down | Code: [`agents_md.rs` L125-L178](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/core/src/agents_md.rs#L125-L178). `remaining` starts at the budget and drops after each file |
| The docs contradict each other on this | The [AGENTS.md guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md) says "combined size". [Config: advanced](https://learn.chatgpt.com/docs/config-file/config-advanced#project-instructions-discovery) says "how much to read from each `AGENTS.md` file". The [config reference](https://learn.chatgpt.com/docs/config-file/config-reference) says "Maximum bytes read from `AGENTS.md`". The code matches the AGENTS.md guide |
| The file that crosses the budget is cut partway through, so its end is what disappears | Code: `data.truncate(remaining as usize)` in [`agents_md.rs` L156-L158](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/core/src/agents_md.rs#L156-L158). The docs only say Codex "stops adding files" |
| Files after the cut never load | Code: the `if remaining == 0 { break; }` loop in [`agents_md.rs` L145-L148](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/core/src/agents_md.rs#L145-L148) |
| The only warning is a line in the Codex log | Code: `tracing::warn!(... "project doc exceeds remaining budget; truncating")` at [`agents_md.rs` L160-L166](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/core/src/agents_md.rs#L160-L166). The TUI's default log filter is `codex_core=info` ([`startup_orchestration.rs`](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/tui/src/startup_orchestration.rs)). Live run: see section 4 |
| Your global `~/.codex/AGENTS.md` doesn't count toward the budget | Code: loaded separately by [`codex-home/src/instructions/mod.rs` L41-L85](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/codex-home/src/instructions/mod.rs#L41-L85), with no byte limit. The project loop in `agents_md.rs` subtracts only project files |
| The chain starts at the git root | Code: `DEFAULT_PROJECT_ROOT_MARKERS = [".git"]` in [`project_root_markers.rs` L5](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/config/src/project_root_markers.rs#L5). Docs: [AGENTS.md guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md) |

## 2. Which file loads in each folder

| Claim | Evidence |
|---|---|
| At most one file per folder: `AGENTS.override.md`, then `AGENTS.md`, then fallback names | Docs: [AGENTS.md guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md). Code: `candidate_filenames` in [`agents_md.rs`](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/core/src/agents_md.rs#L272-L296) |
| **An empty override still wins and hides the AGENTS.md beside it** | Code: `agents_md_paths` takes the first candidate where `metadata.is_file` is true, with no size check ([L254](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/core/src/agents_md.rs#L254)). `read_agents_md` then drops it if the text is only whitespace ([L169](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/core/src/agents_md.rs#L169)). The docs say empty files are skipped, which suggests a fallback that doesn't happen. Covered by `test.sh`. **Live check, 2026-10-17, codex-cli 0.163.0:** with an empty `svc/AGENTS.override.md`, `codex exec` in `svc/` quoted only the root rule. After deleting the empty override, it quoted both the root rule and the `svc/AGENTS.md` rule |
| The global file is different: an empty global override *does* fall back to the global AGENTS.md | Code: [`codex-home/src/instructions/mod.rs` L43-L80](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/codex-home/src/instructions/mod.rs#L43-L80) returns only the first *non-empty* file |
| Codex walks from the git root down to the folder you started in, then stops | Docs: [AGENTS.md guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md) ("Codex stops searching once it reaches your current directory"). Code: `agents_md_paths` |
| Other filenames only count if they're in `project_doc_fallback_filenames` | Docs: [AGENTS.md guide, Customize fallback filenames](https://learn.chatgpt.com/docs/agent-configuration/agents-md) |

## 3. Untrusted folders

| Claim | Evidence |
|---|---|
| **A folder saved as untrusted loads no project AGENTS.md at all, only your global file** | Code: `load_project_instructions` returns early when `config.active_project.is_untrusted()` ([`agents_md.rs` L58-L66](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/core/src/agents_md.rs#L58-L66)) |
| This applies only to an explicit `trust_level = "untrusted"`, not an unset one | Code: `is_untrusted` matches only `Some(TrustLevel::Untrusted)` ([`config_toml.rs`](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/config/src/config_toml.rs)) |
| The docs list what untrusted projects skip, and don't mention AGENTS.md | Docs: [Config basics](https://learn.chatgpt.com/docs/config-file/config-basic) and [Config: advanced](https://learn.chatgpt.com/docs/config-file/config-advanced) ("project-local config, hooks, and rules") |

## 4. The live run (Fail File #1)

Recorded by Darin on 2026-10-16:
- **Codex:** `codex-cli 0.163.0`, model `gpt-6.1-sol`
- **Repo:** a sparse clone of `apache/airflow` (default branch) holding only its AGENTS.md files
- **Folder:** started in `registry/`

| Step | What happened |
|---|---|
| Default budget, question 1: list every section heading, without opening files | The list ended at **"Common Issues"**. In `registry/AGENTS.md` that heading starts at byte 9,774, and the next heading ("CSS Deletion Guidelines") starts at byte 10,115, just past the 10,034-byte cut |
| Default budget, question 2: what do your instructions say about the deployment architecture? | "The provided project instructions don't specify the registry's deployment architecture or hosting setup." |
| The Codex log | `WARN ... agents_md.load{max_total=32768}: codex_core::agents_md: project doc exceeds remaining budget; truncating path=file:///Users/[home]/labs/airflow/registry/AGENTS.md remaining_bytes=10034` |
| The TUI's warnings panel (F2) | Only an unrelated startup warning (command-line overrides need embedded mode). No truncation warning on screen |
| `agents-budget.sh` | `22465  registry/AGENTS.md  CUT: first 10034 bytes load, last 12431 never do` |
| `-c project_doc_max_bytes=65536`, question 2 again | A full answer covering the S3 build, CloudFront serving, the path prefix and the separate site changes. That text sits at bytes 12,257 and later of `registry/AGENTS.md`. Codex: "I opened no files." The log showed `max_total=65536` and no truncation warning |

To reproduce it, follow [FAIL-FILE-01.md](FAIL-FILE-01.md).

## 5. The 12-repo check

- **Method:** see [data/public-repos-2026-10-16.json](data/public-repos-2026-10-16.json) (GitHub tree API) and [data/full-checkout-2026-10-16.txt](data/full-checkout-2026-10-16.txt) (full sparse checkouts with `examples/measure-public-repos.sh`).
- **Result:** 8 of 12 repos have at least one folder Codex would cut off on default settings.
- **The numbers change.** Two of these files grew on 2026-10-16 itself:
  - Grafana `pkg/router/AGENTS.md` went from 30,254 to 31,265 bytes.
  - Pydantic AI's root `AGENTS.md` went from 17,349 to 18,211 bytes.
  - The videos use the evening numbers. Rerun the script for today's.
- **What the numbers mean.** These are well-run projects that may write AGENTS.md for several coding agents. The numbers show Codex's default behavior, not a mistake by the projects.

## 6. Other claims in the videos

| Claim | Evidence |
|---|---|
| Codex builds the instruction chain once per run (once per session in the TUI), with no cache to clear | Docs: [AGENTS.md guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md) |
| `codex --ask-for-approval never "Summarize the current instructions."` shows what loaded | Docs: [AGENTS.md guide, Verify your setup](https://learn.chatgpt.com/docs/agent-configuration/agents-md) |
| The quick fix is a bigger `project_doc_max_bytes` (the docs show 65536) | Docs: [AGENTS.md guide](https://learn.chatgpt.com/docs/agent-configuration/agents-md). Passing it with `-c` works, but Codex then shows a startup warning about embedded mode. Setting it in `~/.codex/config.toml` doesn't |
