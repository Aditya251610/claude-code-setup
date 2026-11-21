# agent-board

A docked pane beside the chat that shows your token budget and lets you inspect any subagent.

## What you see
- **TOKENS:** context fill, the 5-hour and 7-day limit windows with reset times, the session's estimated cost (API rates, not a charge) and tokens per model since the mod loaded.
- **AGENTS:** a one-line summary of running subagents.
- **Agent details:** press `↓` under the prompt, pick a subagent and press `Enter`. The chat shows its conversation and the pane shows its model, elapsed time, context bar, output tokens, estimated cost, what it is doing now and its recent tool calls.
- **Buttons:** `Back` returns to the main chat. `Stop` kills the agent and asks for a second press within 5 seconds.
- **The `↓` list:** each row also shows the agent's latest activity, tokens and cost.

## Use
- It opens by itself. `/board` brings it back if you closed it (the ✕ only hides it).
- Buttons take the mouse, or press `ctrl+x` then `Tab` to give the pane the keyboard.
- It needs about 110 terminal columns; `/board` says so when there is no room.

## Notes
- The pane is transparent, so a glassy terminal shows through. Colours are Claude Code theme keys.
- Tunables are constants at the top of `hooks/agent-board.mjs` (`RECENT`, `CONFIRM_MS`).

Part of [claude-code-setup](../../README.md). Mods run inside Claude Code with your permissions and are not sandboxed: read `hooks/` before installing. Remove with `claude plugin uninstall agent-board`.
