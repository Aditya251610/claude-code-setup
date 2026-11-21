---
name: handoff
description: Write a short handoff note of where the work stands so a fresh session can continue without re-reading everything. Use when ending a session, before /clear, or when context is getting large.
---

Write `HANDOFF.md` in the project root (or print it if the user prefers) with, in this order and under 40 lines:
1. **Goal**: one sentence.
2. **Done**: what is finished and verified.
3. **State**: branch, uncommitted files, failing tests, running processes.
4. **Next**: the next 1 to 3 concrete steps, with exact file paths and commands.
5. **Decisions and gotchas**: things a new session would otherwise rediscover.
Do not paste code or long logs; point to paths. Do not commit the file.
