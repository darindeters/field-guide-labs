# tool-audit

Companion lab for **Claude Field Guide #10: How to Secure a Claude Agent with Tool Access in Production**.

The video ends with one action: audit your tool list per role. This script does the first pass for you.

An agent can leak data when a single role has all three of these:

1. **Private data in context.** It can read your files.
2. **Untrusted content.** It reads text that an outsider controls: a web page, an issue, an MCP server's output.
3. **An outbound tool.** It can send data somewhere.

Remove any one and the path closes. The common way it reopens: someone adds a tool for debugging and never removes it from the production role.

## Run it

```bash
python3 tool-audit.py examples/prod-role.json examples/prod-role-after-debug.json
```

```
examples/prod-role.json
  private data     Read, Grep
  untrusted input  mcp__github__get_issue
  outbound         none
  triangle: OPEN (no outbound tool)
examples/prod-role-after-debug.json
  private data     Read, Grep
  untrusted input  mcp__github__get_issue, WebFetch
  outbound         WebFetch
  triangle: COMPLETE (private data + untrusted input + outbound)
```

The exit code is 1 when any file completes the triangle, so it works as a CI gate on your `.claude/settings.json`.

## What it matches

| Bucket | Allowed rules that count |
|---|---|
| private data | `Read`, `Grep`, `Glob` |
| untrusted input | `WebFetch`, `WebSearch`, any `mcp__*` tool |
| outbound | `WebFetch`, `WebSearch`, bare `Bash` or `Bash(*)`, and `Bash(...)` rules that start with a network command (`curl`, `wget`, `nc`, `ssh`, `scp`, `rsync`, `ftp`, `telnet`) |

A deny rule for the same tool, or the same tool and specifier, removes it. Deny rules win in Claude Code too ([permissions docs](https://code.claude.com/docs/en/permissions)).

## Limits

This checks the rules as written. It doesn't model Claude Code's full permission engine.

- Each file is audited on its own. Claude Code merges managed, user, project and local settings, so audit the files that make up the role together, or the merged result.
- It doesn't inspect what an MCP server can do. Every `mcp__*` tool counts as untrusted input, and none count as outbound. If an MCP tool can send email or post to a URL, treat it as outbound yourself.
- `Bash(npm test *)` counts as not outbound. A test script can still make network calls. The sandbox is the control for that ([sandboxing docs](https://code.claude.com/docs/en/sandboxing)).
- See the [deny-rule-gap](../deny-rule-gap) lab for why a `Bash(curl *)` deny rule alone isn't a boundary.

`test.sh` covers the examples and the edge cases above, and runs in CI.
