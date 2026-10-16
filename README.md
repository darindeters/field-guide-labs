# Field Guide Labs

Companion code for the **Field Guide** videos on [Tech with Darin](https://www.youtube.com/@techwithdarin): Claude, Codex, and the cloud platforms they run on.

Every lab here backs a claim from a video with something you can run yourself. Scripts, test repos, CI checks, and the raw data behind any numbers shown on screen.

## Labs

| Lab | Video | What it does |
|---|---|---|
| [codex/agents-budget](codex/agents-budget) | Codex Field Guide #1: Why Codex Ignores Half Your AGENTS.md (in production) | Shows how much of your AGENTS.md chain Codex actually loads, and where the cut lands. Works as a CI gate. |

## How these labs are built

- **Sources first.** Each lab says which docs page, source file, or dataset it is based on, and when it was checked. Tools change. If a lab drifts from current behavior, open an issue.
- **Tested.** Each lab ships with a self-test that runs in CI on every push.
- **No secrets, ever.** Labs run against throwaway repos or public data. Nothing here needs your API keys.

## License

MIT. See [LICENSE](LICENSE).

Newsletter: [techwithdarin.com](https://www.techwithdarin.com)
