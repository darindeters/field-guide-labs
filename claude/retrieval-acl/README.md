# retrieval-acl

Companion lab for **Claude Field Guide #10: How to Secure a Claude Agent with Tool Access in Production**, chapter "RBAC at Retrieval".

A rule like "do not reveal finance data to engineers" in the system prompt still lets the finance data into the prompt. The model reads it, and one instruction is the only thing between that text and the answer. Enforce access at retrieval instead, before the prompt is built. By the time Claude reads anything, the docs a user can't see are already gone. Think of a library that keeps the restricted books in a locked room, not on the open shelf with a "please don't read" sign.

This lab is a toy retriever over six fictional docs. Each doc has an `acl` list in its front matter. The script drops the docs the role can't see first, then ranks what is left, then prints the context that would go into the prompt.

## Run it

No API key and no network. Python 3 standard library only.

```bash
python3 retrieve.py --no-acl --role engineer "q3 numbers"
```

Recorded output, Oct 17, 2026:

```
role engineer | ACL off, the rule lives in the system prompt
ACL filter    skipped, 6 of 6 docs searchable
query match   4 docs for "q3 numbers"
context for the prompt:
  [all]     Q3 incidents (fictional): 4 incidents, MTTR 41 min. Fake numbers.
  [finance] Q3 payroll (fictional): Payroll $4.2M, 38 staff. Fake numbers.
  [all]     Q3 roadmap (fictional): Ship search API, p95 under 200 ms.
  [finance] Q3 vendor spend (fictional): Vendor spend $610K, mostly hosting.
system prompt: "Do not reveal finance data to non-finance users."
docs this role should not see, in context: 2
```

```bash
python3 retrieve.py --role engineer "q3 numbers"
```

```
role engineer | ACL on, enforced at retrieval
ACL filter    6 docs -> 4, removed 2 before ranking
query match   2 docs for "q3 numbers"
context for the prompt:
  [all]     Q3 incidents (fictional): 4 incidents, MTTR 41 min. Fake numbers.
  [all]     Q3 roadmap (fictional): Ship search API, p95 under 200 ms.
docs this role should not see, in context: 0
```

Run it as `--role finance` and the payroll and vendor docs come back, and the engineer-only on-call doc drops out.

## How it works

1. **Filter.** Keep a doc only if its `acl` contains the role or `all`.
2. **Rank.** Count query words in the title and body. Only filtered docs are scored.
3. **Build context.** Print title and first line for each match. This is what a real app would paste into the prompt.

`--no-acl` skips step 1 and adds the prompt rule instead, so you can see what that approach actually sends to the model.

## Notes and limits

- All six docs are fictional. Every number in them is made up.
- The role comes from a command-line flag here. In production it comes from the authenticated user's identity, never from the model or the prompt.
- Keyword scoring keeps the demo readable. The same rule applies to a vector store: filter on metadata in the query itself, so restricted chunks never come back from the index.
- Filtering after ranking works too, as long as it runs before prompt construction. Filtering before ranking also keeps restricted docs from shaping scores or counts that a user might see.
- `test.sh` checks that the engineer role never gets a finance doc for several queries, that the finance role does, and that `--no-acl` shows the leak. It runs in CI.
