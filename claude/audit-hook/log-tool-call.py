#!/usr/bin/env python3
"""Claude Code PreToolUse hook: append one actor-attributed JSONL line per tool call.

Reads the hook input JSON on stdin. Writes to $TOOL_CALL_LOG, or to
tool-calls.jsonl next to this script. The actor comes from $AGENT_ACTOR,
which your launcher sets from the signed-in user. Falls back to "unknown".

It never blocks: no stdout, exit 0 on every path, even bad input.
Exit 0 with no output lets the call continue through normal permissions.
"""
import datetime
import json
import os
import sys

MAX = 80


def summarize(tool_input, cwd):
    if not isinstance(tool_input, dict):
        return str(tool_input)[:MAX]
    for key in ("command", "file_path", "path", "pattern", "url", "query"):
        if key in tool_input:
            value = str(tool_input[key])
            if cwd:  # show paths relative to the session folder
                root = cwd.rstrip("/")
                value = value.replace(root + "/", "").replace(root, ".")
            return f"{key}={value}"[:MAX]
    return json.dumps(tool_input, sort_keys=True)[:MAX]


def main():
    log = os.environ.get("TOOL_CALL_LOG") or os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "tool-calls.jsonl")
    try:
        event = json.load(sys.stdin)
    except Exception:
        event = {}
    if not isinstance(event, dict):
        event = {}
    line = {
        "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "actor": os.environ.get("AGENT_ACTOR") or "unknown",
        "session_id": event.get("session_id", "unknown"),
        "tool_name": event.get("tool_name", "unknown"),
        "input": summarize(event.get("tool_input"), event.get("cwd", "")),
    }
    with open(log, "a", encoding="utf-8") as f:
        f.write(json.dumps(line, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # logging must never break the agent
        print(f"log-tool-call: {exc}", file=sys.stderr)
    sys.exit(0)
