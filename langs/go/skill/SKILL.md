---
name: go-best-practices
description: Go playbook for building or learning: module layout, errors, context, concurrency, race detector, go vet. Use when asked how to structure, test, make concurrent, or improve a Go project, or to explain Go practice.
---

Use only for Go. Answer from this, adapted to what the project already does.

## Layout
- `go.mod` at the root; commands in `cmd/<name>/main.go`; private packages in `internal/`. A small module can keep everything in the root.

## Errors and context
- Handle errors early; wrap with `%w` only when the cause is part of your API (wrapping makes the inner error something callers can depend on). Use `errors.Is` and `errors.As`.
- `ctx` first, never in a struct, always `defer cancel()`; `go vet` includes the lostcancel check.

## Testing and checks
- `*_test.go` beside the code. Run `go vet ./...` and `go test -race ./...`.
- The race detector only finds races on paths that actually run, costs roughly 5 to 10 times the memory and 2 to 20 times the time, and needs cgo. `GORACE="halt_on_error=1" go test -race` stops at the first report. `//go:build !race` skips a test that cannot run under it.

## Pitfalls
- Leaked goroutines; copying types that contain locks; assuming `-race` proves safety; `util` packages; interfaces defined by the producer instead of the consumer.

Sources: Effective Go, Go Code Review Comments, Go race detector article, Go 1.13 errors post, Go context blog, Go module layout guide, `go vet` docs.
<!-- managed by claude-code-setup -->
