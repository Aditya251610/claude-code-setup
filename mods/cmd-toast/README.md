# Command Toast

Shows a short toast when a shell command starts, a live running timer in the status entry while it runs, and a toast with the exit status, the time and the last four lines of output when it ends. Claude Code does not stream a command's output to mods, so output appears when the command ends. Commands started in the background are announced but not followed.

Part of [claude-code-setup](../../README.md). Install with `claude plugin install cmd-toast@claude-code-setup --scope user` after adding the marketplace (the installer does both). Mods run inside Claude Code with your permissions and are not sandboxed: read the source in `hooks/` before installing. Remove with `claude plugin uninstall cmd-toast`.
