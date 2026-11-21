---
name: commit
description: Write a short conventional commit message for the staged changes and commit. Use when the user says commit, or asks for a commit message.
---

1. Run `git status --short` and `git diff --staged --stat`. If nothing is staged, say so and stop; never `git add -A` on your own.
2. Read the staged diff (`git diff --staged`) only if the stat is not enough to name the change.
3. Message: `type(scope): summary` in the imperative, at most 72 characters. Types: feat, fix, refactor, perf, test, docs, chore, build, ci.
4. Add a body only when the *why* is not obvious from the summary: at most 3 short lines.
5. Commit with that message. Do not push. Do not add attribution lines unless the project or the user's instructions ask for them.
