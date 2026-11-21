# Global defaults

## Models and effort
- **Default for everything: Sonnet 5.5 (`claude-sonnet-5-5`) at medium effort.** This includes planning, debugging, research and review. Never move these to a weaker model to save tokens.
- **Opus 5.5 (`claude-opus-5-5`) is the exception, not a tier.** Use it only for a *complex* research or debugging task that the user says has already taken **more than 3 hours** (or after two failed approaches in a long session). Start at medium effort; go higher only if still stuck.
  - You cannot change your own model. Say so plainly and recommend `/model claude-opus-5-5` then `/effort medium`, or delegate one `researcher` call with `model: "opus"`. Do not switch silently.
- **Haiku 5.5 only for repetitive, mechanical coding** (renames, boilerplate, bulk edits, formatting, running a test suite) through the `worker` agent, with exact instructions. Never for planning, debugging, research or review.
- **Reviews use `reviewer` (Sonnet).** Only a very specialised case (security-critical code, subtle concurrency or memory-safety bugs) may use Opus or higher effort, and only when the user agrees.

## Subagents
- At most **3 running at once**; prefer 0 or 1. Delegate only when the work is large or noisy and the parent needs just a summary. Do not delegate when the parent needs the reasoning.
- Agents available: `researcher` (read-only research and exploration), `reviewer` (read-only review), `worker` (cheap mechanical edits).
- Ask subagents for a short result (about 300 words), not a transcript.

## Saving tokens
- Search first (`grep`/glob), then read only the needed lines (`offset`/`limit`). Use exact file paths when the user gives them.
- Do not re-read files already in context. Do not paste long logs; show the relevant lines.
- Keep answers short; skip recaps of work the user just watched.
- Suggest `/compact <what to keep>` or `/clear` between unrelated tasks, and the `handoff` skill before ending a long session.

## Context and auto-compact
- Auto-compact runs when the context reaches **60% of a 1M window (600k tokens)**. It is set with `CLAUDE_CODE_AUTO_COMPACT_WINDOW=633000` in `settings.json` (the threshold sits 33k tokens below that window).
- Do not wait for it. Between unrelated tasks, or at a natural stopping point, suggest `/compact <what to keep>`; before ending a long session use the `handoff` skill.

## Working style
- Use the project's own tooling and config first. Language-specific defaults (Python, Rust, Go, C/C++, TypeScript) live in `~/.claude/rules/` when installed and load only when matching files are touched.
- Verify claims by running things where practical, and report failures plainly.
- Commit or push only when the user asks for that exact action in that message. An earlier approval does not carry over to later changes, and "don't commit" stands for the rest of the session. Staging, diffs and status are fine.
- Do not run destructive commands unless asked.
