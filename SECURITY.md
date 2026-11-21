# Security

## What to know before installing
- **Mods are not sandboxed.** They are Claude Code plugins and run with your permissions. Read `mods/*/hooks/` before installing, or install with `--no-mods`.
- **Skills and agents are instructions** your agent follows with your permissions. They are plain Markdown; read them in `skills/`, `agents/` and `langs/`.
- **The installer** only writes under `~/.claude/` and `~/.local/share/claude-code-setup/`, never uses `sudo`, and backs up what it replaces to `~/.claude/backups/`. Preview exactly what it will do with `--dry-run`, or download `install.sh` and read it before running it.
- **Pin a release** with `--version vX.Y.Z` if you do not want the latest `main`.

## Supported versions
The latest release.

## Reporting a vulnerability
Please report privately through GitHub's "Report a vulnerability" option on the repository's Security tab. If that is not available, open an issue that asks for a private channel and leave out the details of the problem. Do not include secrets, tokens or personal data.
