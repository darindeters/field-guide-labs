#!/usr/bin/env python3
"""Audit a Claude Code settings file for the exfiltration triangle.

An agent can leak data when one role has all three at once:
  1. private data in context    (it can read your files)
  2. untrusted content          (it reads text an outsider controls)
  3. an outbound tool           (it can send data somewhere)

This reads permissions.allow and permissions.deny and sorts each allowed
tool into those buckets. Deny rules win, as they do in Claude Code. It is a
quick check of the rules as written, not a full model of Claude Code's
permission engine. See README.md for exactly what it matches.

Usage: tool-audit.py SETTINGS.json [SETTINGS.json ...]
Exit code: 1 if any file completes the triangle, else 0.
"""
import json
import re
import sys

PRIVATE = {"Read", "Grep", "Glob"}
UNTRUSTED = {"WebFetch", "WebSearch"}
OUTBOUND = {"WebFetch", "WebSearch"}
NET_COMMANDS = ("curl", "wget", "nc", "ncat", "ssh", "scp", "rsync", "ftp", "telnet")
RULE = re.compile(r"^([A-Za-z0-9_\-]+)(?:\((.*)\))?$")


def parse(rule):
    m = RULE.match(rule.strip())
    return (m.group(1), m.group(2)) if m else (rule.strip(), None)


def classify(rule):
    tool, spec = parse(rule)
    kinds = set()
    if tool in PRIVATE:
        kinds.add("private data")
    if tool in UNTRUSTED or tool.startswith("mcp__"):
        kinds.add("untrusted input")
    if tool in OUTBOUND:
        kinds.add("outbound")
    if tool == "Bash":
        first = (spec or "").split()[0] if spec else ""
        if spec is None or spec.strip() in ("*", ":*") or first in NET_COMMANDS:
            kinds.add("outbound")
    return kinds


def denied(rule, deny):
    tool, spec = parse(rule)
    for d in deny:
        dt, ds = parse(d)
        if dt == tool and (ds is None or ds == spec):
            return True
    return False


def audit(path):
    perms = json.load(open(path)).get("permissions", {})
    allow, deny = perms.get("allow", []), perms.get("deny", [])
    buckets = {"private data": [], "untrusted input": [], "outbound": []}
    for rule in allow:
        if denied(rule, deny):
            continue
        for kind in classify(rule):
            buckets[kind].append(rule)
    print(path)
    for kind, rules in buckets.items():
        print(f"  {kind:<16} {', '.join(rules) if rules else 'none'}")
    missing = [k for k, v in buckets.items() if not v]
    if missing:
        names = {"private data": "private data", "untrusted input": "untrusted input", "outbound": "outbound tool"}
        print(f"  triangle: OPEN (no {' or '.join(names[k] for k in missing)})")
        return False
    print("  triangle: COMPLETE (private data + untrusted input + outbound)")
    return True


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip().splitlines()[-2], file=sys.stderr)
        return 2
    complete = [audit(p) for p in argv[1:]]
    return 1 if any(complete) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
