---
name: setup-claude-code
description: Set up, update, check or remove the claude-code-setup global Claude Code configuration (model and effort policy, three subagents, six skills, token-saving deny rules, optional mods) on this machine. Use when the user asks to set up Claude Code, install claude-code-setup, apply their Claude Code setup, update it, check it, or uninstall it.
---

# Set up Claude Code with claude-code-setup

Source: https://github.com/Aditya251610/claude-code-setup (MIT). It installs into `~/.claude/` through its own `install.sh`. Use that script; do not hand-edit `~/.claude/settings.json` or `~/.claude/CLAUDE.md` to imitate it.

## What it installs

- A managed block in `~/.claude/CLAUDE.md`: Sonnet 5.5 at medium effort for everything; Opus 5.5 only for a complex task the user says has taken over 3 hours; Haiku 5.5 only for mechanical edits through the `worker` agent; at most 3 subagents at once; auto-compact at 60% of a 1M window (`CLAUDE_CODE_AUTO_COMPACT_WINDOW=633000` in settings).
- Settings merged into `~/.claude/settings.json`: the model and effort pin, the subagent cap, and deny rules that keep `node_modules`, virtualenvs, lockfiles and similar out of context. The user's other settings are kept.
- Agents `researcher`, `reviewer` and `worker`, and skills `commit`, `pr-summary`, `review`, `debug-loop`, `grill-me`, `handoff`.
- Optional mods (Claude Code plugins): `agent-board`, `cmd-toast`, `big-read-guard`, `done-notify`, `blast-radius`. **Mods run inside Claude Code with the user's permissions and are not sandboxed.**

The installer backs up whatever it replaces to `~/.claude/backups/`, never uses `sudo`, and is safe to re-run.

## Steps

1. **Check the basics.** `git --version`, `jq --version`, `claude --version`. If `jq` or `git` is missing, tell the user which command installs it for their system and stop; do not install system packages yourself. Mods need Claude Code 2.1.287 or newer.

2. **Ask before changing anything.** Ask these in one message, with the defaults in brackets:
   - Pin the default model and effort in `settings.json`? [yes; `--no-model-pin` says no]
   - Install the mods? [yes; tell them they are unsandboxed and can read `mods/*/hooks/*.mjs` first; `--no-mods` says no]
   - Language servers? [none; `--lsp python,rust,cpp,go` picks languages; this only adds Claude Code plugins and prints the commands for the servers, which the user runs]

3. **Get the source.** If `~/.local/share/claude-code-setup` exists, run `git -C ~/.local/share/claude-code-setup pull --ff-only`. Otherwise `git clone --depth 1 https://github.com/Aditya251610/claude-code-setup ~/.local/share/claude-code-setup`.

4. **Preview.** Run `./install.sh --dry-run` from that folder, with the flags from step 2. Summarise what it would change in a few lines. If the user's `~/.claude/settings.json` already has a `model` or `effortLevel` and pinning is on, say so: it will be replaced (backed up first) and uninstall will leave the pin in place.

5. **Install.** Run `./install.sh` with the same flags. If it exits non-zero, show the last lines of its output and stop; do not retry blindly and do not edit files by hand to work around it. The installer records what it added, so `./uninstall.sh` still works after a partial run.

6. **Verify.** Run `claude plugin list` (the mods should show as enabled, if installed), `ls ~/.claude/agents ~/.claude/skills`, and check that `~/.claude/CLAUDE.md` contains `claude-code-setup:begin`. Report anything missing.

7. **Tell the user to restart Claude Code.** New settings, agents, skills and mods load at the start of a session. Mention `/board` (reopens the board if they close it), and that they open a subagent from the board by pressing `↓` under the prompt, choosing one and pressing Enter.

## Update, check, remove

- **Update:** `git -C ~/.local/share/claude-code-setup pull --ff-only`, then `./install.sh` again (same flags). Retired mods are removed automatically.
- **Check:** `./install.sh --dry-run` shows what differs, and changes nothing.
- **Remove:** `./uninstall.sh` removes the skill links, agent files, the `CLAUDE.md` block, the settings entries it added and the plugins. Backups stay in `~/.claude/backups/`.

## Rules

- Never run with `sudo`. Never pipe the installer to a shell without the user seeing the dry run first.
- Do not commit, push or change the repository; it is only the source.
- If something is unclear (a different Claude config directory, a managed or locked settings file), set `CLAUDE_CONFIG_DIR` only if the user says so, and otherwise ask.
