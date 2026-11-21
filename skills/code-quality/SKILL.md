---
name: code-quality
description: A language-agnostic production-quality checklist for writing or reviewing code (errors, logging, constants, retries, naming). Use when asked to make code production-ready, to review for robustness, or before shipping a change.
---

Check the code against these, in any language, and report only what is violated, with file and line:

1. **No swallowed errors.** Every `catch` / `except` / ignored error result does something observable: log it, surface it, or rethrow. No empty handlers.
2. **No silent defaults.** Missing required data fails loudly or is surfaced; it is never replaced by a made-up default.
3. **Named constants.** No magic numbers or strings; give each a name that says what it is.
4. **No boolean flag parameters** that change what a function does; split into two named functions.
5. **Bounded retries.** At most 3 attempts with exponential backoff; never an unbounded loop. Writes that must not repeat are idempotent (unique key, upsert, or an idempotency key).
6. **Traceable failures.** Every error or log at a decision point carries the IDs needed to find the cause (request, user, record).
7. **Clear names and plain control flow.** Explicit `if`/`else` over clever one-liners; names that say exactly what the code does.
8. **Resources are released** on every path (files, connections, locks, goroutines or tasks have an owner that stops them).

Do not rewrite code that passes. If a rule does not apply to the language or the project, say so in one line and skip it.
