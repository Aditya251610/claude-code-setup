# Command Toast

Quiet by default: short commands show nothing. It speaks up only for long-running ones.

- **Background commands:** a toast when one starts, a live line in the status area that follows the command's output file (its latest line, refreshed every 2 seconds), and a toast with the exit code and the last lines when it ends.
- **Foreground commands over 10 seconds:** a toast when the command passes the mark, a live timer in the status area, and a toast with the result and the last lines when it ends. Claude Code does not expose a foreground command's output before it ends, so it cannot be shown live.
- **Why the live view is a status line:** a toast cannot be updated in place, a status line can.

Tune `LONG_SECS` and `POLL_MS` at the top of `hooks/cmd-toast.mjs`.

Part of [claude-code-setup](../../README.md). Install with `claude plugin install cmd-toast@claude-code-setup --scope user` after adding the marketplace (the installer does both). Mods run inside Claude Code with your permissions and are not sandboxed: read the source in `hooks/` first. Remove with `claude plugin uninstall cmd-toast`.
