# audit-hook

Companion lab for **Claude Field Guide #10: How to Secure a Claude Agent with Tool Access in Production**, chapter "Per-user credentials and actor-attributed logs".

When every user's agent runs on one shared key, every tool call looks the same in your logs. You can see that a file was read. You can't see who asked for it. This lab ties each tool call to an actor with a Claude Code `PreToolUse` hook that appends one JSONL line per call.

## Files

- `log-tool-call.py` reads the hook input JSON on stdin and appends one line to `tool-calls.jsonl`: time, actor, session ID, tool name, and a short summary of the tool input. The actor comes from the `AGENT_ACTOR` environment variable, with `unknown` as the fallback.
- `settings.json` registers the script as a `PreToolUse` hook for every tool (`"matcher": "*"`). It uses exec form (`command` plus `args`) so the `${CLAUDE_PROJECT_DIR}` path needs no shell quoting.

The hook never blocks. It prints nothing to stdout and exits 0 on every path, including bad input. Per the [hooks docs](https://code.claude.com/docs/en/hooks), exit 0 with no output means the hook has no decision, and the call continues through the normal permission flow. Schema checked against that page on Oct 17, 2026.

## Run it

From this folder, with Claude Code installed and signed in:

```bash
AGENT_ACTOR=alice@example.com claude -p "List the files in this folder and read README.md's first line. Answer in one short sentence." --settings settings.json --setting-sources project --tools "Read,Glob,Bash" < /dev/null
tail -n 3 tool-calls.jsonl
```

Recorded output, Oct 17, 2026 (Claude Code 2.1.302):

```
The folder holds .gitignore, README.md, log-tool-call.py, settings.json, test.sh, and tool-calls.jsonl, and README.md's first line is `# audit-hook`.
```

```
{"ts":"2026-10-17T08:49:09Z","actor":"alice@example.com","session_id":"1f0656ab-4f31-4286-8d49-f8dbb49768d1","tool_name":"Bash","input":"command=ls -la ."}
{"ts":"2026-10-17T08:49:09Z","actor":"alice@example.com","session_id":"1f0656ab-4f31-4286-8d49-f8dbb49768d1","tool_name":"Read","input":"file_path=README.md"}
```

Claude picks its own tools, so your run may log a `Glob`, or a single `Bash` call, instead. Each one gets a line with the actor.

## What the flags do

- `--settings settings.json` loads the hook from this folder.
- `--setting-sources project` skips your user settings, so your own hooks don't mix in.
- `--tools "Read,Glob,Bash"` limits the session to three built-in tools.
- `< /dev/null` stops `claude -p` from waiting for piped input.

## Notes and limits

- `AGENT_ACTOR` is set by whoever launches the agent. In production, your gateway or job runner sets it from the authenticated user, the same identity that picks that user's credentials. A value the user or the model can change is not an audit trail.
- The log sits next to the script and is gitignored. Point `TOOL_CALL_LOG` at another path to move it. In production, ship these lines to an append-only store the agent can't write to.
- The hook logs attempts. A call that the permission system later denies still gets a line. Add a `PostToolUse` hook if you also want outcomes.
- Paths inside the session folder are logged as relative paths, and the input summary is cut at 80 characters. Don't log full tool inputs without checking them for secrets first.
- `test.sh` feeds sample hook JSON on stdin and checks the JSONL line, the `unknown` fallback, bad input, and `settings.json`. It runs in CI without a Claude login.
