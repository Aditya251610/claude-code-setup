# done-notify

A desktop notification when Claude finishes a long turn, so you can look away while it works.

## What it does
- Fires when a turn on the main loop takes 45 seconds or more. Subagent turns and interrupted turns do not notify.
- Uses `notify-send` on Linux and `osascript` on macOS. If neither exists it stays quiet.

## Notes
- Change `MIN_SECONDS` at the top of `hooks/done-notify.mjs` to tune the threshold.
- The macOS path is written but not tested on a Mac.

Part of [claude-code-setup](../../README.md). Mods run inside Claude Code with your permissions and are not sandboxed: read `hooks/` before installing. Remove with `claude plugin uninstall done-notify`.
