# claude-code-setup

An opinionated, token-frugal global setup for [Claude Code](https://code.claude.com): a model and effort policy, three subagents, six skills, deny rules that keep junk out of the context, and a set of mods (an agent and token board, command toasts, a big-read guard, done notifications).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Aditya251610/claude-code-setup/main/install.sh | bash
```

Prefer to read it first?

```bash
git clone https://github.com/Aditya251610/claude-code-setup && cd claude-code-setup
./install.sh --dry-run     # shows exactly what would change, changes nothing
./install.sh
```

Works on Linux, macOS and WSL. Needs `jq` and `git`; the mods need Claude Code 2.1.287 or newer. It never uses `sudo`, backs up whatever it replaces to `~/.claude/backups/`, and is safe to re-run.

| Option | Effect |
| --- | --- |
| `--dry-run` | Preview only. |
| `--no-model-pin` | Do not set the default model and effort in `settings.json`. |
| `--no-mods` | Skip the mods. |
| `--lsp python,rust,cpp,go` | Also install the language-server plugins and print the commands for the servers. |

Remove everything it added with `./uninstall.sh`.

## What you get

**Model policy** (in the managed block it adds to `~/.claude/CLAUDE.md`, and pinned in `settings.json`)
- Sonnet 5.5 at medium effort for everything, including planning, debugging, research and review.
- Opus 5.5 only for a complex research or debugging task that has already taken more than 3 hours.
- Haiku 5.5 only for repetitive, mechanical coding through the `worker` agent.
- At most 3 subagents running at once (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`).

**Agents** (`~/.claude/agents/`): `researcher` (read-only research), `reviewer` (read-only review, Sonnet), `worker` (cheap mechanical edits, Haiku).

**Skills** (`~/.claude/skills/`, symlinked so `git pull` updates them): `commit`, `pr-summary`, `review`, `debug-loop`, `grill-me`, `handoff`.

**Settings**: deny rules for `node_modules`, virtualenvs, `__pycache__`, `target/`, minified files, source maps and lockfiles; merged into your existing `settings.json`, never replacing it.

**Mods** (Claude Code plugins that run inside the app; they are **not sandboxed and run with your permissions**, so read `mods/*/hooks/` first):

| Mod | What it does |
| --- | --- |
| `agent-board` | Docked pane: context, 5-hour and weekly limits, per-model tokens, estimated cost, and a details view for any subagent you open (what it is doing, tokens, cost, Back and Stop). |
| `cmd-toast` | Quiet by default: toasts and a live status line only for background and long-running commands. |
| `big-read-guard` | Refuses whole-file reads of huge or generated files. |
| `done-notify` | Desktop notification when a long turn finishes. |
| `blast-radius` | Holds risky commands and shows what they would change (Anthropic sample). |

## Using the board
- It opens by itself beside the chat; `/board` brings it back if you closed it (the ✕ only hides it).
- Subagents are not shown all the time. Press `↓` under the prompt, pick one and press `Enter`: the chat shows its conversation and the board shows its details. `Back` returns to the main chat.
- Each `↓` row also shows the agent's latest activity, tokens and cost.
- `Stop` asks twice (press it again within 5 seconds) because it kills the agent.
- Buttons take the mouse, or their hotkey after `ctrl+x` then `Tab` gives the board the keyboard.

## Development
`scripts/test.sh` runs every mod's tests and validates the plugins and the marketplace.

## Notes
- The mods draw no fixed colours: panes are transparent (a glassy terminal shows through), borders and meaning use Claude Code theme keys, and text uses your terminal's foreground. For colours that follow your terminal's own palette, pick an ANSI theme with `/theme`.
- Token and cost figures are estimates at API rates. On a subscription the cost is not a charge.
- Claude Code does not expose a foreground Bash command's output before it ends, so `cmd-toast` follows live output only for background commands (through their output file); foreground ones show it when they end.
- A top-level `effortLevel` does not apply to Opus 5.5; set effort for Opus with `/effort`.
- `blast-radius` is Anthropic's sample from [claude-code-playground](https://github.com/anthropics/claude-code-playground), copied under Apache-2.0 with two changes, a transparent pane background and theme-key colours (see `NOTICE`).

## License
MIT, except the two vendored mods (Apache-2.0).
