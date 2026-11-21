# Command Toast

Quiet by default: short commands show nothing. It speaks up only for long-running ones.

- **Background commands:** a toast when one starts, a live card above the prompt that follows the command's output file (refreshed every 2 seconds), and a toast with the exit code and the last lines when it ends.
- **Foreground commands over 10 seconds:** a toast when the command passes the mark, a live card with a timer, and a toast with the result and the last lines when it ends. Claude Code does not expose a foreground command's output before it ends, so the card says so instead of showing it.
- **The card:** `▶ command  1:42  [Expand] [×]`. Expand shows the full command and the last 8 lines of output. × only hides the card; it never stops the command. A finished card disappears after about 20 seconds unless it is expanded. Click a button, or press `ctrl+x` then `Tab` to focus the band and use `Tab` and `Enter`.
- **No status line.** A native toast is plain text that cannot change once shown, which is why the live timer, the expansion and the × live in a card in the band above the prompt. (`blast-radius` uses the same band in a narrow terminal.)

Tune `LONG_SECS` and `POLL_MS` at the top of `hooks/cmd-toast.mjs`.

Part of [claude-code-setup](../../README.md). Install with `claude plugin install cmd-toast@claude-code-setup --scope user` after adding the marketplace (the installer does both). Mods run inside Claude Code with your permissions and are not sandboxed: read the source in `hooks/` first. Remove with `claude plugin uninstall cmd-toast`.
