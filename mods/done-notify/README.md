# Done Notify

Sends a desktop notification when a turn on the main loop takes 45 seconds or more, so you can look away while Claude works. Uses notify-send on Linux and osascript on macOS; if neither exists it stays quiet. Change MIN_SECONDS in hooks/done-notify.mjs to tune it.

Part of [claude-code-setup](../../README.md). Install with `claude plugin install done-notify@claude-code-setup --scope user` after adding the marketplace (the installer does both). Mods run inside Claude Code with your permissions and are not sandboxed: read the source in `hooks/` before installing. Remove with `claude plugin uninstall done-notify`.
