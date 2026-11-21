---
name: pr-summary
description: Draft a pull request title and description from the current branch's commits and diff. Use when the user wants a PR description or asks what a branch changes.
---

1. Find the base: `git merge-base HEAD origin/HEAD` (fall back to `main`/`master`).
2. Look at `git log --oneline <base>..HEAD` and `git diff <base>...HEAD --stat`. Read individual diffs only for files that matter.
3. Output exactly:
   - **Title**: at most 70 characters, imperative.
   - **What changed**: 3 to 6 bullets, grouped by behaviour, not by file.
   - **Why**: one or two sentences.
   - **How to test**: concrete commands or steps.
   - **Risks / follow-ups**: only if real.
4. Do not create the PR, push, or edit anything unless the user asks.
