# cmd-toast

Quiet by default. It only speaks up for commands that run long or in the background.

## What you see
- **Background commands:** a toast when one starts, a live card above the prompt that follows the command's output file (refreshed every 2 seconds), and a toast with the exit code and the last lines when it ends.
- **Foreground commands over 10 seconds:** a toast at the 10-second mark, a live card with a timer, and a toast with the result and the last lines when it ends. Claude Code does not expose a foreground command's output before it ends, so the card says so instead of showing it.
- **The card:** `▶ command  1:42  [Expand] [×]`. Expand shows the full command and the last 8 lines of output. **× only hides the card; it never stops the command.** A finished card disappears after about 20 seconds unless you expanded it.

## Use
Click a button, or press `ctrl+x` then `Tab` to focus the band above the prompt, then `Tab` and `Enter`.

## Notes
- A native toast is plain text that cannot change once shown, which is why the live timer, the expansion and the × live in a card and not in the toast.
- There is no status line.
- The card uses the band above the prompt, which `blast-radius` also uses in a narrow terminal. In a wide terminal they do not collide.
- Tunables are constants at the top of `hooks/cmd-toast.mjs` (`LONG_SECS`, `POLL_MS`, `DONE_LINGER_MS`, `MAX_CARDS`, `CARD_LINES`).

Part of [claude-code-setup](../../README.md). Mods run inside Claude Code with your permissions and are not sandboxed: read `hooks/` before installing. Remove with `claude plugin uninstall cmd-toast`.
