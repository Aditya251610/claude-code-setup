---
name: rust-best-practices
description: Rust playbook for building or learning: Cargo layout, testing, error handling, clippy, unsafe and Miri, common pitfalls. Use when asked how to structure, test, lint or improve a Rust project, or to explain Rust practice.
---

Use only for Rust. Answer from this, adapted to what the project already does.

## Layout (Cargo book)
- `Cargo.toml` and `Cargo.lock` at the root; `src/lib.rs`, `src/main.rs`, `src/bin/`; `tests/`, `examples/`, `benches/`. A multi-file target goes in a subdirectory with a `main.rs`. Binary and test names use kebab-case.

## Testing (Rust Book ch. 11)
- Unit tests in `#[cfg(test)] mod tests` beside the code. Integration tests in `tests/`, one crate per file; shared helpers in `tests/common/mod.rs`. `cargo test` also runs doc tests. Integration tests can only import a library crate, which is why logic belongs in `lib.rs`.

## Errors
- `Result` for failures a caller can handle; `panic!` or `unwrap` when a contract is broken. `clippy::unwrap_used` is a restriction lint you opt into.

## Lints and unsafe
- `cargo clippy --all-targets` clean. To make warnings fatal use `-- -D warnings` (Cargo 1.97 and later also have `CARGO_BUILD_WARNINGS=deny`, which the Clippy docs prefer because `-D warnings` invalidates build caches). `cargo clippy --fix` applies suggestions.
- Miri (`cargo +nightly miri test`) checks `unsafe` code, but only the paths that run, and a clean run does not prove the code correct.

## Pitfalls
- `overflow-checks` and `debug-assertions` are on in dev and off in release, so behaviour can differ. `panic` unwinds by default. `static mut` risks data races. Large `unsafe` blocks. Unwrap-driven control flow where `Result` belongs.

Sources: The Rust Book (ch. 9, 11, 20), the Rustonomicon, Rust API Guidelines checklist, Cargo book (project layout, profiles), Clippy usage docs. `cargo fmt` itself was not documented with `--check` on the page checked.
<!-- managed by claude-code-setup -->
