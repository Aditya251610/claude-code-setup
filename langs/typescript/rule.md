---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/tsconfig.json"
---

# TypeScript guardrails
The project's own config (tsconfig, eslint, CI) wins over these. For a fuller guide, use the typescript-best-practices skill.
- Keep `"strict": true`. Check with `npx tsc --noEmit` (or the project's typecheck script) after changes.
- No `any`: fix implicit-any errors; use `unknown` and narrow it. Narrow `null` and `undefined` with real checks; use `!` only when it is certain, with a comment.
- `as` is erased at compile time and checks nothing at runtime: prefer narrowing, or go through `unknown`. Validate external data at the boundary.
- `strict` does not include `noUncheckedIndexedAccess`; suggest it when code indexes arrays or records.
- `interface` for object shapes; `type` for unions, intersections and aliases.
- Lint with typescript-eslint (`npx eslint .`). Prefer a type-aware config; `@typescript-eslint/no-floating-promises` catches forgotten `await`.
- Use the package manager the lockfile shows (npm, pnpm, yarn or bun).
<!-- managed by claude-code-setup -->
