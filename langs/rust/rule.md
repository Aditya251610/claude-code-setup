---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
---

# Rust guardrails
The project's own config (Cargo.toml lints, rust-toolchain, CI) wins over these. For a fuller guide, use the rust-best-practices skill.
- After editing: `cargo fmt`, `cargo clippy --all-targets -- -D warnings`, `cargo test`. Use `cargo check` while iterating.
- Return `Result` for expected failures. `panic!` and `unwrap` are for broken contracts, tests and examples; an `expect` message must say why the call cannot fail.
- Keep logic in `src/lib.rs` and `main.rs` thin, so integration tests can reach it.
- Keep `unsafe` blocks minimal, wrapped in a safe function that checks the preconditions, each with a `// SAFETY:` comment; an `unsafe fn` documents a `# Safety` section. Use `#![forbid(unsafe_code)]` where none is needed. Run `cargo +nightly miri test` after any `unsafe` change.
- Unsafe code must not rely on caller-supplied safe code (closures, generic trait impls) for memory safety.
- API shape: `as_` / `to_` / `into_` names, `Debug` on public types, private struct fields, newtypes, and document errors, panics and safety.
- When the borrow checker complains, explain the ownership or lifetime problem in a line or two before fixing it; do not `clone` just to silence it.
<!-- managed by claude-code-setup -->
