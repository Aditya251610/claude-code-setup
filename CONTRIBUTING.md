# Contributing

Issues and pull requests are welcome.

## Run the tests
```bash
scripts/test.sh            # every mod's tests, plugin validation, shell syntax, installer round trip
scripts/test-install.sh    # bash installer: install, update and uninstall in a throwaway home (no mods, nothing real is touched)
scripts/test-install-ps.sh # the same for install.ps1 (needs pwsh; skipped if it is missing)
```
They need the `claude` CLI and `jq`. Keep them green.

## Guidelines
- **Small and reversible.** The installer must stay idempotent, back up what it replaces, never use `sudo`, and record everything it adds so `uninstall.sh` can remove it.
- **Portable shell.** Keep `install.sh` and `uninstall.sh` working on bash 3.2 (macOS) and without GNU-only flags. Every `jq` `if` needs an `else` (jq 1.6).
- **Windows.** Keep `install.ps1` and `uninstall.ps1` ASCII-only and compatible with PowerShell 5.1 (no `??`, ternary or `&&`; wrap one-item arrays as `@(,@(...))`). Mods must not call Unix tools (`tail`, `uname`); use the `$.fs` and `$.session.info()` APIs.
- **Short instructions.** Anything always loaded (`CLAUDE.md`) costs tokens in every session. Prefer path-scoped rules and on-demand skills.
- **Claims need evidence.** Say what you tested. Say "not tested" where that is the case.

## Add a language
Create `langs/<name>/rule.md` (frontmatter with a `paths:` list, then a short checklist) and `langs/<name>/skill/SKILL.md` (`name: <name>-best-practices`, a description that says when to use it, sources at the end). End each file with `<!-- managed by claude-code-setup -->`. Add the name to the `--lang` handling in `install.sh` and a check in `scripts/test-install.sh`. Cite official sources and keep each language free of another's tools.

## Add a mod
Put it in `mods/<name>/` with `.claude-plugin/plugin.json` (include `license`), `hooks/hooks.json`, the module in `hooks/`, a `README.md`, and a `*.test.ts` using `claude-code/testing`. List it in `.claude-plugin/marketplace.json`. Mods run unsandboxed, so keep them small and readable.

## Commits
Short imperative subject, then a few lines on what and why.
