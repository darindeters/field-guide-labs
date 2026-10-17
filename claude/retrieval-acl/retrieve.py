#!/usr/bin/env python3
"""Toy retrieval step that enforces access control BEFORE ranking.

Usage:
  python3 retrieve.py --role engineer "q3 numbers"
  python3 retrieve.py --no-acl --role engineer "q3 numbers"

Every doc in docs/ has front matter with a title and an acl list, for
example `acl: [finance]` or `acl: [all]`. With the ACL on, docs the role
cannot see are dropped before scoring, so they never reach the prompt.
With --no-acl, every doc is searchable and the only guard is a line in
the system prompt, which is what "put the rules in the prompt" amounts to.
"""
import argparse
import os
import re
import sys

ROLES = ("engineer", "finance")
PROMPT_RULE = "Do not reveal finance data to non-finance users."
WIDTH = 80


def load_docs(folder):
    docs = []
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".md"):
            continue
        with open(os.path.join(folder, name), encoding="utf-8") as f:
            text = f.read()
        m = re.match(r"---\n(.*?)\n---\n(.*)", text, re.S)
        if not m:
            sys.exit(f"{name}: missing front matter")
        meta = {}
        for line in m.group(1).splitlines():
            key, _, value = line.partition(":")
            meta[key.strip()] = value.strip()
        acl = [a.strip() for a in meta.get("acl", "").strip("[]").split(",") if a.strip()]
        if not acl:
            sys.exit(f"{name}: empty acl")
        body = m.group(2).strip()
        docs.append({
            "file": name,
            "title": meta.get("title", name),
            "acl": acl,
            "first": body.splitlines()[0] if body else "",
            "text": (meta.get("title", "") + " " + body).lower(),
        })
    return docs


def allowed(doc, role):
    return "all" in doc["acl"] or role in doc["acl"]


def score(doc, terms):
    words = re.findall(r"[a-z0-9]+", doc["text"])
    return sum(words.count(t) for t in terms)


def fit(line):
    return line if len(line) <= WIDTH else line[: WIDTH - 3] + "..."


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--role", required=True, choices=ROLES)
    ap.add_argument("--no-acl", action="store_true",
                    help="skip the ACL filter, rely on a prompt instruction")
    ap.add_argument("--docs", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "docs"))
    ap.add_argument("query")
    args = ap.parse_args()

    docs = load_docs(args.docs)
    terms = re.findall(r"[a-z0-9]+", args.query.lower())

    # Step 1: access control. Runs before ranking, before prompt construction.
    if args.no_acl:
        visible = docs
        print(f"role {args.role} | ACL off, the rule lives in the system prompt")
        print(f"ACL filter    skipped, {len(docs)} of {len(docs)} docs searchable")
    else:
        visible = [d for d in docs if allowed(d, args.role)]
        removed = len(docs) - len(visible)
        print(f"role {args.role} | ACL on, enforced at retrieval")
        print(f"ACL filter    {len(docs)} docs -> {len(visible)}, removed {removed} before ranking")

    # Step 2: rank only what the role is allowed to see.
    hits = sorted(((score(d, terms), d) for d in visible), key=lambda p: (-p[0], p[1]["file"]))
    hits = [d for s, d in hits if s > 0]
    print(f"query match   {len(hits)} docs for \"{args.query}\"")

    # Step 3: the context that would go into the prompt.
    print("context for the prompt:")
    for d in hits:
        tag = "[" + ",".join(d["acl"]) + "]"
        print(fit(f"  {tag:<10}{d['title']}: {d['first']}"))
    if args.no_acl:
        print(f"system prompt: \"{PROMPT_RULE}\"")

    leaked = [d for d in hits if not allowed(d, args.role)]
    print(f"docs this role should not see, in context: {len(leaked)}")


if __name__ == "__main__":
    main()
