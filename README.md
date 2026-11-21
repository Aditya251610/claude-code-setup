<h1 align="center">claude-code-setup</h1>

<p align="center">
  A token-frugal, safe-by-default global setup for <a href="https://code.claude.com">Claude Code</a>.<br>
  One command installs a model policy, subagents, skills, language guardrails and a set of mods.
</p>

<p align="center">
  <a href="https://github.com/Aditya251610/claude-code-setup/releases"><img alt="Release" src="https://img.shields.io/github/v/release/Aditya251610/claude-code-setup"></a>
  <img alt="License" src="https://img.shields.io/badge/license-MIT%20%2B%20Apache--2.0-blue">
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Linux%20%C2%B7%20macOS%20%C2%B7%20Windows%20%C2%B7%20WSL-lightgrey">
</p>

<p align="center">
  <a href="#quick-start">Quick start</a> ·
  <a href="#what-you-get">What you get</a> ·
  <a href="#languages">Languages</a> ·
  <a href="#mods">Mods</a> ·
  <a href="#what-the-installer-changes">What it changes</a> ·
  <a href="#faq">FAQ</a>
</p>

## Why

- **Spend fewer tokens.** One model and effort policy, a cap on parallel subagents, auto-compact at 60% of the window, and deny rules that keep `node_modules`, lockfiles and other junk out of the context.
- **Safer defaults.** Commits and pushes only on an explicit ask, risky shell commands held for your approval, and huge or generated files refused before they flood the context.
- **See what is going on.** A board for context, limits, cost and subagents, plus live cards for long-running commands.
- **Language help only when it is needed.** Python, Rust, Go, C/C++ and TypeScript guidance that loads for that language's files and never mixes with another's.

## Quick start

**macOS, Linux and WSL**

```bash
curl -fsSL https://raw.githubusercontent.com/Aditya251610/claude-code-setup/main/install.sh | bash
```

**Windows (PowerShell, no admin needed)**

```powershell
irm https://raw.githubusercontent.com/Aditya251610/claude-code-setup/main/install.ps1 | iex
```

No clone and no `git` needed. Restart Claude Code afterwards, then check `/plugin` and `/agents`.

Add the options you want:

```bash
curl -fsSL https://raw.githubusercontent.com/Aditya251610/claude-code-setup/main/install.sh \
  | bash -s -- --lang python,rust,go,cpp,ts --style terse
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Aditya251610/claude-code-setup/main/install.ps1))) -Lang python,rust,go,cpp,ts -Style terse
```

<details>
<summary><b>Read it first, let your agent do it, or install on any OS through Claude Code itself</b></summary>

Download, read, preview, then run (macOS, Linux, WSL):

```bash
curl -fsSLO https://raw.githubusercontent.com/Aditya251610/claude-code-setup/main/install.sh
less install.sh
bash install.sh --dry-run     # shows exactly what would change, changes nothing
bash install.sh
```

On Windows: `irm .../install.ps1 -OutFile install.ps1`, read it, then `.\install.ps1 -DryRun` and `.\install.ps1`.

Let your agent do it: add just the setup skill and ask Claude Code to "set up Claude Code with claude-code-setup". It checks the basics, asks what you want, shows the dry run, installs and verifies:

```bash
npx skills add Aditya251610/claude-code-setup --skill setup-claude-code -g -a claude-code
```

Mods or skills only, on any OS, with Claude Code's own tools and no installer:

```
/plugin marketplace add Aditya251610/claude-code-setup
/plugin install agent-board@claude-code-setup
```
```bash
npx skills add Aditya251610/claude-code-setup -g -a claude-code    # the everyday skills
```

To pin a release instead of the latest: `... | bash -s -- --version v0.2.1` or `-Version v0.2.1` (any tag from the [releases](https://github.com/Aditya251610/claude-code-setup/releases)).

</details>

### Requirements

| | |
| --- | --- |
| Systems | **macOS, Linux and WSL** with `install.sh`. **Windows** (PowerShell 5.1 or 7, no admin rights) with `install.ps1`. |
| Needs | `install.sh`: `bash`, `curl`, `tar`, `jq` (`brew install jq`, `sudo apt install jq`, `sudo pacman -S jq`). `install.ps1`: nothing extra. |
| Claude Code | The mods need 2.1.287 or newer. Skills, agents, rules and settings work on any recent version. |
| `blast-radius` | Anthropic's sample runs `bash` and `git`. On Windows install [Git for Windows](https://git-scm.com/download/win), which provides both. |
| Tested | Linux (Arch): the bash installer end to end. The PowerShell installer: every check passes under PowerShell 7 on Linux, **not yet on a Windows machine**. macOS: the scripts avoid GNU-only flags and bash 4 features, **not yet run on a Mac**. The mods' platform code (file reads, notifications) is covered by unit tests for all four platforms. Please open an issue if something breaks. |

On Windows the skills are **copied, not symlinked** (symlinks need Developer Mode or admin rights), so re-run the installer to update them. Windows paths: config in `%USERPROFILE%\.claude` (or `CLAUDE_CONFIG_DIR`), downloaded copy in `%LOCALAPPDATA%\claude-code-setup`.

It never uses `sudo` or admin rights, backs up whatever it replaces to `~/.claude/backups/`, and is safe to re-run.

## What you get

| | |
| --- | --- |
| **Model policy** | Sonnet 5.5 at medium effort for everything, including planning, debugging, research and review. Opus 5.5 only for a complex task that has already taken more than 3 hours. Haiku 5.5 only for mechanical edits, through the `worker` agent. |
| **Subagent cap** | At most 3 running at once (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`). |
| **Auto-compact** | At 60% of a 1M window, 600k tokens (`CLAUDE_CODE_AUTO_COMPACT_WINDOW=633000`). Measured: the engine reports a threshold of exactly 600,000. |
| **Agents** | `researcher` (read-only research), `reviewer` (read-only review, Sonnet), `worker` (cheap mechanical edits, Haiku). |
| **Skills** | `commit`, `pr-summary`, `review`, `debug-loop`, `grill-me`, `handoff`, `code-quality`, and `setup-claude-code`. |
| **Deny rules** | `node_modules`, virtualenvs, `__pycache__`, `target/`, minified files, source maps and lockfiles, merged into your existing `settings.json`. |
| **Commit safety** | Commit or push only when you ask for that exact action. An earlier approval does not carry over, and "don't commit" stands for the session. |
| **Mods** | Five Claude Code plugins, see [Mods](#mods). |
| **Languages** *(opt-in)* | Guardrails and playbooks for Python, Rust, Go, C/C++ and TypeScript, see [Languages](#languages). |
| **Terse style** *(opt-in)* | An output style with short bullets and no recap. Switch it on or off any time with `/output-style`. |

### Install options

On Windows the same options are PowerShell parameters: `-DryRun`, `-Version`, `-NoModelPin`, `-NoMods`, `-Lang`, `-Style`, `-Lsp`.

| Option | Effect |
| --- | --- |
| `--dry-run` | Preview only. |
| `--version vX.Y.Z` | Install a tagged release instead of the latest. |
| `--no-model-pin` | Do not set the default model and effort in `settings.json`. |
| `--no-mods` | Skip the mods. |
| `--lang python,rust,go,cpp,ts` | Install language guardrails and playbooks. Prints any toolchain you are missing. |
| `--style terse` | Install and select the Terse output style. |
| `--lsp python,rust,cpp,go,ts` | Also install the language-server plugins and print the commands for the servers. |

## Languages

Each language is self-contained under [`langs/`](langs) and installs two small pieces that never mix with another language's:

- **Guardrails** (`~/.claude/rules/<language>.md`): a short checklist that loads only when Claude touches that language's files.
- **Playbook** (`<language>-best-practices` skill): a fuller guide to layout, testing, tooling and pitfalls that loads only when you ask about that language.

| Language | Guardrails cover | Main tools |
| --- | --- | --- |
| Python | imports, `except`, typing, `uv` environments | `ruff`, `pytest`, `uv` |
| Rust | `Result` over `unwrap`, `unsafe` hygiene, API shape | `cargo fmt`, `clippy`, `cargo test`, Miri |
| Go | error wrapping, `context`, goroutine ownership | `gofmt`, `go vet`, `go test -race` |
| C / C++ | RAII, sanitizers, CMake targets, `clang-tidy` | `cmake`, ASan and UBSan, `clang-tidy` |
| TypeScript | `strict`, no `any`, narrowing over casts | `tsc --noEmit`, `typescript-eslint` |

They are written from official sources (PEP 8 and ruff, the Rust Book and Cargo book, Effective Go, the C++ Core Guidelines, the TypeScript handbook and others), and each playbook lists its sources. Your project's own configuration always wins over them.

## Mods

Mods are Claude Code plugins that run inside the app. **They are not sandboxed and run with your permissions, so read `mods/*/hooks/` before installing.**

| Mod | What it does |
| --- | --- |
| [`agent-board`](mods/agent-board) | Side pane with context, 5-hour and weekly limits, per-model tokens and estimated cost. Open any subagent to see what it is doing, with Back and Stop. |
| [`cmd-toast`](mods/cmd-toast) | Quiet by default. Long and background commands get a toast and a live card with a timer, an expandable command and output, and a × that only hides the card. |
| [`big-read-guard`](mods/big-read-guard) | Refuses whole-file reads of huge or generated files and asks for a range or a search instead. |
| [`done-notify`](mods/done-notify) | A desktop notification when a long turn finishes. |
| [`blast-radius`](mods/blast-radius) | Holds risky commands (`rm -rf`, `git reset --hard`, force pushes, migrations) and shows what they would change. Anthropic's sample, Apache-2.0. |

### Using the board

- It opens by itself beside the chat. `/board` brings it back if you closed it (the ✕ only hides it).
- Subagents are not listed all the time. Press `↓` under the prompt, pick one and press `Enter`: the chat shows its conversation and the board shows its details. `Back` returns to the main chat.
- Each `↓` row also shows the agent's latest activity, tokens and cost.
- `Stop` asks twice (press it again within 5 seconds), because it kills the agent.
- Buttons take the mouse, or `ctrl+x` then `Tab` gives the pane the keyboard.

## What the installer changes

| Where | What | Removed by uninstall |
| --- | --- | --- |
| `~/.local/share/claude-code-setup/` (Windows: `%LOCALAPPDATA%\claude-code-setup`) | A downloaded copy of this repo. Mods load from it, and on macOS and Linux the skills link into it. | Stays; delete it yourself if you like. |
| `~/.claude/skills/` | Symlinks to the skills (copies on Windows). | Yes |
| `~/.claude/agents/` | Copies of the three agents. | Yes |
| `~/.claude/rules/`, `output-styles/` | Only the languages and style you chose. | Yes |
| `~/.claude/CLAUDE.md` | A marked block; the rest of the file is untouched. | Yes |
| `~/.claude/settings.json` | Merged, never replaced: model and effort, two env values, 12 deny rules, the output style if you chose one. Your other settings stay. | Yes (your own model setting is left alone) |
| Claude Code plugins | The five mods, and any language servers you chose. | Yes |
| `~/.claude/backups/` | A copy of anything it replaced. | Stays |

The installer records everything it adds in `~/.claude/.claude-code-setup.manifest`, which `uninstall.sh` reads.

## Update, pin and uninstall

- **Update:** run the install command again. It refreshes the downloaded copy and keeps your choices.
- **Pin a version:** add `--version vX.Y.Z`.
- **Uninstall:** `~/.local/share/claude-code-setup/uninstall.sh` (Windows: `& "$env:LOCALAPPDATA\claude-code-setup\uninstall.ps1"`). Backups made by the installer stay in `~/.claude/backups/`.

## FAQ

**Does this add a lot to every session?**
The always-loaded part is a short managed block in `CLAUDE.md` plus the names and descriptions of the skills. Language guardrails load only for matching files, and playbooks only when invoked.

**Can I use just the skills?**
Yes: `npx skills add Aditya251610/claude-code-setup -g -a claude-code` adds the skills only, with no settings, agents or mods.

**Are the cost figures a bill?**
No. They are estimates at API rates. On a subscription nothing is charged per token.

**I want a different model policy.**
Run the installer with `--no-model-pin` and set your own `model` in `settings.json`. The policy text lives in the managed block of `~/.claude/CLAUDE.md`, which re-running the installer rewrites, so keep your own instructions outside the markers.

**Why is the board transparent?**
It paints no background, so a glassy or blurred terminal shows through. Colours are Claude Code theme keys, so the board follows your theme.

**Some details of how Claude Code behaves.**
Claude Code does not expose a foreground command's output before it ends, so `cmd-toast` shows live output only for background commands. A top-level `effortLevel` does not apply to Opus 5.5; set effort for Opus with `/effort`.

## Development

```bash
scripts/test.sh            # every mod's tests, plugin validation, shell syntax, installer round trip
scripts/test-install.sh    # bash installer: install, update and uninstall in a throwaway home
scripts/test-install-ps.sh # PowerShell installer, same checks (needs pwsh; skipped if missing)
```

Contributions are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md). To report a security problem, see [SECURITY.md](SECURITY.md). Release notes are in [CHANGELOG.md](CHANGELOG.md).

## License

MIT, except [`mods/blast-radius`](mods/blast-radius), which is Anthropic's sample from [claude-code-playground](https://github.com/anthropics/claude-code-playground) and stays under Apache-2.0 (see [`LICENSE-APACHE-2.0`](LICENSE-APACHE-2.0) and [`NOTICE`](NOTICE)).
