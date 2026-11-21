# Changelog

All notable changes to this project. Versions follow [semantic versioning](https://semver.org); dates are release dates.

## 0.3.0 - 2026-11-21
### Added
- **Windows:** `install.ps1` and `uninstall.ps1` (PowerShell 5.1 and 7, no admin rights). They copy skills instead of symlinking, keep the same manifest and settings merge as the bash installer, and are covered by `scripts/test-install-ps.sh`.
- Mods and skills install on any OS through Claude Code's own `/plugin marketplace add` and `npx skills add`, documented in the README.
### Changed
- `cmd-toast` reads output files with the file API instead of `tail`, and `done-notify` detects the platform through `$.session.info()` and gains a Windows (PowerShell toast) path, so the mods work on Windows. Tests cover all four platforms.
- The manifest is tab-separated, so a home folder with a space in its name (common on macOS and Windows) no longer breaks uninstall. Older space-separated manifests are still read.
- The installer no longer needs `git` or a clone: it downloads a release tarball with `curl` and `tar` into `~/.local/share/claude-code-setup`. Re-running it refreshes that copy.
- `--version vX.Y.Z` installs a tagged release instead of the latest.
- Portability: explicit `mktemp` templates, no bash 4-only features, a clear message on native Windows pointing to WSL.
- README, security and contributing docs, and the mod READMEs rewritten.

## 0.2.1 - 2026-11-21
### Fixed
- `blast-radius` declares its Apache-2.0 license in its plugin metadata, and the README names the one vendored mod.

## 0.2.0 - 2026-11-21
### Added
- Opt-in language packs for Python, Rust, Go, C/C++ and TypeScript: guardrails that load only for that language's files, and playbook skills that load only when asked (`--lang`).
- Terse output style (`--style terse`), the `code-quality` skill, and the `setup-claude-code` skill for agent-driven setup (`npx skills add`).
- Auto-compact at 60% of a 1M window, and a stricter commit and push rule.
- `agent-board`: open any subagent from the `↓` list to see its activity, tokens and cost, with Back and Stop. The `↓` rows show the same.
- `cmd-toast`: a live card above the prompt with a timer, an expandable command and output, and a × that only hides the card.
- `scripts/test.sh` and `scripts/test-install.sh`.
### Changed
- Mods follow the Claude Code theme and draw transparent panes. No status line.
- The install manifest now accumulates across runs, so uninstall never forgets an earlier install, and uninstall keeps your own model and effort settings.
- `done-notify` passes its text to `osascript` as an argument instead of inside the script.
### Removed
- `token-weather`, which overlapped the board and the band that `blast-radius` uses. The installer removes it from earlier installs.
### Fixed
- `cmd-toast` no longer leaves a card stuck on "running" when a command errors or its output file disappears.

## 0.1.0 - 2026-11-21
### Added
- One-line installer for Linux, macOS and WSL with backups, a manifest and an uninstaller.
- Model and effort policy, three subagents (`researcher`, `reviewer`, `worker`), six skills and token-saving deny rules.
- Mods: `agent-board`, `cmd-toast`, `big-read-guard`, `done-notify`, and the vendored `token-weather` and `blast-radius`.
