# Agent Board

A docked pane beside the chat with two parts. TOKENS shows the context fill, the 5-hour and 7-day limit windows with reset times, the session's estimated cost (API rates, not a charge) and tokens per model counted from when the mod loaded. AGENTS shows one tile per running subagent (name, model, elapsed time, tokens, what it is doing), laid out like a tiling window manager: one agent fills the area, two split it, more keep splitting the remainder. Finished agents stay for 30 seconds. Needs about 110 terminal columns; `/board` opens it and says when there is no room.

Part of [claude-code-setup](../../README.md). Install with `claude plugin install agent-board@claude-code-setup --scope user` after adding the marketplace (the installer does both). Mods run inside Claude Code with your permissions and are not sandboxed: read the source in `hooks/` before installing. Remove with `claude plugin uninstall agent-board`.
