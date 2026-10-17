# Field Guide Labs

Companion code for the **Field Guide** videos on [Tech with Darin](https://www.youtube.com/@techwithdarin): Claude, Codex, and the cloud platforms they run on.

Every lab here backs a claim from a video with something you can run yourself. Scripts, test repos, CI checks, and the raw data behind any numbers shown on screen.

## Labs

| Lab | Video | What it does |
|---|---|---|
| [codex/agents-budget](codex/agents-budget) | Codex Field Guide #1: Why Codex Ignores Half Your AGENTS.md (publishing Oct 18) | Shows how much of your AGENTS.md chain Codex actually loads, and where the cut lands. Works as a CI gate. [Sources](codex/agents-budget/SOURCES.md) |
| [codex/agents-budget/FAIL-FILE-01.md](codex/agents-budget/FAIL-FILE-01.md) | Fail File #1: Codex was reading half the rules (publishing Oct 18) | The live run from the video, step by step, with the expected output, so you can reproduce it. |
| [claude/review-blind-spots](claude/review-blind-spots) | Claude Field Guide #9: Why Your AI Code Reviewer Misses Real Bugs (publishing Oct 17) | A demo repo with a staged change that breaks a caller outside the diff. Run a confidence-gated review and a search-and-read review on it. [Sources](claude/review-blind-spots/SOURCES.md) |
| [claude/deny-rule-gap](claude/deny-rule-gap) | Claude Field Guide #10: How to Secure a Claude Agent with Tool Access (publishing Oct 17) | Two commands: a `Bash(curl *)` deny rule blocks `curl`, and the same program by full path goes through. |
| [claude/tool-audit](claude/tool-audit) | Claude Field Guide #10 | Audits a Claude Code settings file for the exfiltration triangle: private data, untrusted input, and an outbound tool in one role. Works as a CI gate. |

Playlists: [Anthropic Claude Field Guide](https://www.youtube.com/playlist?list=PLHnN5yZzJYeI) · [OpenAI Codex Field Guide](https://www.youtube.com/playlist?list=PLFugvr56CiX8)

## How these labs are built

- **Sources first.** Each lab says which docs page, source file, or dataset it is based on, and when it was checked. Tools change. If a lab drifts from current behavior, open an issue.
- **Tested.** Each lab ships with a self-test that runs in CI on every push.
- **No secrets, ever.** Labs run against throwaway repos or public data. Nothing here needs your API keys.

## License

MIT. See [LICENSE](LICENSE).

Newsletter: [techwithdarin.com](https://www.techwithdarin.com)
