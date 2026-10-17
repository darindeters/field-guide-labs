# deny-rule-gap

Companion lab for **Claude Field Guide #10: How to Secure a Claude Agent with Tool Access in Production**.

A Claude Code deny rule like `Bash(curl *)` matches the command text Claude writes. It stops `curl https://example.com`. It does not stop the same program called by its full path, or run through another shell. The [permissions docs](https://code.claude.com/docs/en/permissions) say so directly. This lab shows it in two commands.

## Run it

From this folder, with Claude Code installed and signed in:

```bash
claude -p "Run this exact command and reply with only the HTTP status line: curl -sI https://example.com" --settings rules.json --setting-sources project < /dev/null
```

Recorded output, Oct 17, 2026 (Claude Code 2.1.296):

> The command was denied by the permission system, so I could not run it. No status line is available to report.

```bash
claude -p "Run this exact command and reply with only the HTTP status line: /usr/bin/curl -sI https://example.com" --settings rules.json --setting-sources project < /dev/null
```

Recorded output:

> HTTP/2 200

## What the flags do

- `--settings rules.json` loads the two rules in this folder: permit Bash, deny `Bash(curl *)`.
- `--setting-sources project` skips your user settings, so your own allow rules don't change the result.
- `< /dev/null` stops `claude -p` from waiting for piped input.

## What to do instead

The docs recommend deny rules for whole tool categories, WebFetch domain rules for outbound fetches, and the sandbox for process and network isolation. A command-text pattern is one signal, not a boundary.

- [Permissions: what a Bash rule doesn't match](https://code.claude.com/docs/en/permissions)
- [Bash sandbox](https://code.claude.com/docs/en/sandboxing)

## Notes

- The request goes to example.com, a domain reserved for documentation. Change it if you like. Nothing else leaves your machine.
- Use `-sI` and ask for the status line only. Full response headers can include CDN details, such as the edge location that served you.
- `test.sh` checks that `rules.json` is valid and holds these rules. The live run needs a Claude login, so CI doesn't run it.
