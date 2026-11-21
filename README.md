# claude-code-setup

An opinionated, token-frugal global setup for [Claude Code](https://code.claude.com): a model and effort policy, three subagents, seven skills, opt-in language guardrails and playbooks, deny rules that keep junk out of the context, and a set of mods (an agent and token board, command toasts, a big-read guard, done notifications).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Aditya251610/claude-code-setup/main/install.sh | bash
```

Or let your agent do it. Add just the setup skill, then ask Claude Code to "set up Claude Code with claude-code-setup":

```bash
npx skills add Aditya251610/claude-code-setup --skill setup-claude-code -g -a claude-code
```

The skill walks the agent through the same installer: it checks `git` and `jq`, asks what you want (model pin, mods, language servers), shows the dry run, installs, verifies and tells you to restart. The same command without `--skill` adds the six everyday skills only, with no settings, agents or mods.

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
| `--lang python,rust,go,cpp,ts` | Install language guardrails and playbooks for the languages you pick (see below). Prints any toolchain you are missing. |
| `--style terse` | Install and select the Terse output style (short bullets, no recap). Switch any time with `/output-style`. |
| `--lsp python,rust,cpp,go,ts` | Also install the language-server plugins and print the commands for the servers. |

Remove everything it added with `./uninstall.sh`.

## What you get

**Model policy** (in the managed block it adds to `~/.claude/CLAUDE.md`, and pinned in `settings.json`)
- Sonnet 5.5 at medium effort for everything, including planning, debugging, research and review.
- Opus 5.5 only for a complex research or debugging task that has already taken more than 3 hours.
- Haiku 5.5 only for repetitive, mechanical coding through the `worker` agent.
- At most 3 subagents running at once (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`).
- Auto-compact at 60% of a 1M window (600k tokens), set with `CLAUDE_CODE_AUTO_COMPACT_WINDOW=633000`. Measured: the engine then reports a threshold of exactly 600,000. (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` had no effect in Claude Code 2.1.330, so the window is used instead. On a model with a smaller window, the default threshold still applies.)

**Agents** (`~/.claude/agents/`): `researcher` (read-only research), `reviewer` (read-only review, Sonnet), `worker` (cheap mechanical edits, Haiku).

**Skills** (`~/.claude/skills/`, symlinked so `git pull` updates them): `commit`, `pr-summary`, `review`, `debug-loop`, `grill-me`, `handoff`, and `setup-claude-code` (set up, update or remove this setup from inside Claude Code).

**Settings**: deny rules for `node_modules`, virtualenvs, `__pycache__`, `target/`, minified files, source maps and lockfiles; merged into your existing `settings.json`, never replacing it.

**Mods** (Claude Code plugins that run inside the app; they are **not sandboxed and run with your permissions**, so read `mods/*/hooks/` first):

| Mod | What it does |
| --- | --- |
| `agent-board` | Docked pane: context, 5-hour and weekly limits, per-model tokens, estimated cost, and a details view for any subagent you open (what it is doing, tokens, cost, Back and Stop). |
| `cmd-toast` | Quiet by default. Only background and long-running commands get a toast (start and result) and a live card above the prompt: timer, Expand for the command and its output, × hides the card (it never stops the command). No status line. |
| `big-read-guard` | Refuses whole-file reads of huge or generated files. |
| `done-notify` | Desktop notification when a long turn finishes. |
| `blast-radius` | Holds risky commands and shows what they would change (Anthropic sample). |

## Languages (opt-in)
Each language is its own folder under `langs/` and installs two small pieces that never mix with another language's:
- **Guardrails** (`~/.claude/rules/<language>.md`): a short checklist (formatter, linter, tests, the language's classic traps) that loads only when Claude touches that language's files. A Python session never sees the Rust rules.
- **Playbook** (`~/.claude/skills/<language>-best-practices`): a fuller guide to project layout, testing, tooling and pitfalls that loads only when you ask about that language, for example "how should I set up a Rust project".

They are written from official sources (PEP 8 and ruff, the Rust Book and Cargo book, Effective Go, the C++ Core Guidelines, the TypeScript handbook and others; the sources are listed in each playbook). The project's own config always wins over them. Languages: Python, Rust, Go, C and C++, TypeScript.

## Using the board
- It opens by itself beside the chat; `/board` brings it back if you closed it (the ✕ only hides it).
- Subagents are not shown all the time. Press `↓` under the prompt, pick one and press `Enter`: the chat shows its conversation and the board shows its details. `Back` returns to the main chat.
- Each `↓` row also shows the agent's latest activity, tokens and cost.
- `Stop` asks twice (press it again within 5 seconds) because it kills the agent.
- Buttons take the mouse, or their hotkey after `ctrl+x` then `Tab` gives the board the keyboard.

## Development
`scripts/test.sh` runs every mod's tests and validates the plugins and the marketplace. `scripts/test-install.sh` installs and uninstalls everything into a throwaway home and checks the result.

## Notes
- The mods draw no fixed colours: panes are transparent (a glassy terminal shows through), borders and meaning use Claude Code theme keys, and text uses your terminal's foreground. For colours that follow your terminal's own palette, pick an ANSI theme with `/theme`.
- Token and cost figures are estimates at API rates. On a subscription the cost is not a charge.
- Claude Code does not expose a foreground Bash command's output before it ends, so `cmd-toast` shows live output only for background commands (through their output file); foreground ones show it when they end. A native toast cannot change after it appears, which is why the live timer lives in the card.
- A top-level `effortLevel` does not apply to Opus 5.5; set effort for Opus with `/effort`.
- `blast-radius` is Anthropic's sample from [claude-code-playground](https://github.com/anthropics/claude-code-playground), copied under Apache-2.0 with two changes, a transparent pane background and theme-key colours (see `NOTICE`).

## License
MIT, except the two vendored mods (Apache-2.0).
