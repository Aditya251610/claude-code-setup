---
name: review
description: Review the current uncommitted or branch diff for bugs, risks and missing tests, reported by severity. Use when the user asks for a code review of their changes.
---

Delegate to the `reviewer` agent when the diff is large (over about 300 changed lines); otherwise do it inline.

1. Get the diff: `git diff` (uncommitted) or `git diff <base>...HEAD` (branch). Review only changed lines and what they touch.
2. Report, most severe first, each as `file:line  problem  suggested fix`:
   - **Bug / correctness**: wrong behaviour, edge cases, error handling, concurrency, resource leaks.
   - **Safety**: injection, unvalidated input, secrets, unsafe memory use (C/C++, `unsafe` Rust), data races.
   - **Missing tests** for changed behaviour.
   - **Nits** last, and only a few.
3. Say plainly when nothing important was found. Do not rewrite code unless asked.
4. Language checks: Python (types, mutable defaults, exceptions), Rust (ownership, unwrap/panic paths, `unsafe`), C/C++ (lifetimes, bounds, UB, RAII), Go (error handling, goroutine leaks, `defer` in loops).
