# big-read-guard

Stops a single read from flooding your context.

## What it does
- Refuses a whole-file read of a file over 150 KB, or of generated and vendored files: `node_modules`, virtualenvs, lockfiles, minified code, source maps and build output.
- Tells the model to search with grep, or to read a line range, instead.
- Reads that already give an offset, a limit or pages pass untouched, as do images, PDFs and notebooks.
- If the file size cannot be read, the read is allowed.

## Notes
- The limit is `MAX_BYTES` at the top of `hooks/big-read-guard.mjs`; the patterns are the `GENERATED` list next to it.
- It complements the deny rules the installer adds to `settings.json`.

Part of [claude-code-setup](../../README.md). Mods run inside Claude Code with your permissions and are not sandboxed: read `hooks/` before installing. Remove with `claude plugin uninstall big-read-guard`.
