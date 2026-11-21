---
name: typescript-best-practices
description: TypeScript playbook for building or learning: strict tsconfig, type narrowing, typescript-eslint, common pitfalls. Use when asked how to set up, type, lint or improve a TypeScript project, or to explain TypeScript practice.
---

Use only for TypeScript. Answer from this, adapted to what the project already does.

## Setup
- `tsconfig.json` with `"strict": true`. It enables alwaysStrict, strictNullChecks, strictBindCallApply, strictBuiltinIteratorReturn, strictFunctionTypes, strictPropertyInitialization, noImplicitAny, noImplicitThis and useUnknownInCatchVariables. Upgrading TypeScript can add new strict errors, so budget time for that.
- Typecheck: `npx tsc --noEmit`.
- Lint: `npm i -D eslint @eslint/js typescript typescript-eslint`, then `npx eslint .` with `tseslint.configs.recommended`; step up to `recommendedTypeChecked` or `strictTypeChecked` with `parserOptions.projectService: true`.
- Common layout: `src/`, `tsconfig.json`, `eslint.config.mjs` (convention, not mandated). For tests, use whatever runner the project's `package.json` already has.

## Types
- `interface` for object shapes; `type` for unions, intersections and aliases.
- Narrow instead of asserting. `as` and `!` are erased at compile time, so they hide bugs rather than prevent them.
- `noUncheckedIndexedAccess` is not part of `strict`; it adds `undefined` to index access and is worth enabling.

## Pitfalls
- `any`; unchecked `as` and `!`; typed linting is slower in CI; `strict` plus `recommended` still misses unchecked index access; floating promises.

Sources: TypeScript handbook and tsconfig `strict` reference; typescript-eslint getting started and typed linting.
<!-- managed by claude-code-setup -->
