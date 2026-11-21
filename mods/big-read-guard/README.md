# Big Read Guard

Refuses a whole-file read of a file over 150 KB, or of generated and vendored files (node_modules, virtualenvs, lockfiles, minified code, source maps, build output), and tells the model to grep or to read a line range instead. Reads that already give an offset, a limit or pages pass untouched, as do images, PDFs and notebooks. If the size cannot be read the read is allowed.

Part of [claude-code-setup](../../README.md). Install with `claude plugin install big-read-guard@claude-code-setup --scope user` after adding the marketplace (the installer does both). Mods run inside Claude Code with your permissions and are not sandboxed: read the source in `hooks/` before installing. Remove with `claude plugin uninstall big-read-guard`.
