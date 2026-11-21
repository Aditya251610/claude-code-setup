---
paths:
  - "**/*.go"
  - "**/go.mod"
---

# Go guardrails
The project's own config (go.mod, linter config, CI) wins over these. For a fuller guide, use the go-best-practices skill.
- After editing: `gofmt -l .` (or `go fmt ./...`), `go vet ./...`, `go test ./...`; add `-race` for anything concurrent.
- Never discard an error with `_`. Return errors last and handle them early so the success path stays unindented. Error strings are lowercase with no trailing punctuation.
- Wrap with `fmt.Errorf("doing X: %w", err)` only when callers should be able to inspect the cause; compare with `errors.Is` / `errors.As`, not `==`.
- `context.Context` is the first parameter and is not stored in a struct. Always `defer cancel()`.
- Every goroutine has a clear way to exit and an owner that waits for it. No `panic` for ordinary errors.
- Define interfaces where they are used and return concrete types. No `util` or `common` package names.
<!-- managed by claude-code-setup -->
