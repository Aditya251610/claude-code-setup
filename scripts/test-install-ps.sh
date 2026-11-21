#!/usr/bin/env bash
# Tests install.ps1 and uninstall.ps1 with PowerShell 7 (pwsh) in a throwaway home whose name has a space.
# Skips with a notice if pwsh is not available. Nothing real is touched; no mods are installed.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Resolve the real pwsh binary before HOME is overridden below (a mise shim would break once HOME changes).
PWBIN="$(command -v pwsh 2>/dev/null || true)"
case "$PWBIN" in ""|*/shims/*) PWBIN="$(mise exec powershell@latest -- bash -c 'command -v pwsh' 2>/dev/null || true)" ;; esac
[ -n "$PWBIN" ] || { echo "pwsh not found: skipping the PowerShell installer test"; exit 0; }
PW=("$PWBIN")
command -v jq >/dev/null 2>&1 || { echo "jq is needed for this test"; exit 1; }
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ccs.XXXXXX")"; SB="$ROOT/Jane Smith"; mkdir -p "$SB/.claude"; trap 'rm -rf "$ROOT"' EXIT
export HOME="$SB" CLAUDE_CONFIG_DIR="$SB/.claude" CCS_HOME="$SB/ccs-copy"; unset USERPROFILE LOCALAPPDATA
C="$CLAUDE_CONFIG_DIR"; fail=0
check() { if eval "$2"; then printf '  ok    %s\n' "$1"; else printf '  FAIL  %s\n' "$1"; fail=1; fi; }
psrun() { "${PW[@]}" -NoProfile -File "$@"; }
echo '{"theme":"dark","model":"claude-sonnet-5-5"}' > "$C/settings.json"; echo "my own rule" > "$C/mine.md"

psrun ./install.ps1 -NoMods -Lang python,go,ts -Style terse >/dev/null 2>&1
check "install.ps1 exits 0" "[ \$? -eq 0 ]"
check "skills are copied with a marker (no symlinks)" "[ -f '$C/skills/commit/SKILL.md' ] && [ -f '$C/skills/commit/.ccs-managed' ] && [ ! -L '$C/skills/commit' ]"
check "agents installed" "[ -f '$C/agents/researcher.md' ] && grep -q 'managed by claude-code-setup' '$C/agents/worker.md'"
check "language rules and playbooks installed, one per language" "[ -f '$C/rules/python.md' ] && [ -f '$C/rules/go.md' ] && [ -f '$C/rules/typescript.md' ] && [ -f '$C/skills/go-best-practices/SKILL.md' ] && [ ! -e '$C/rules/rust.md' ]"
check "terse style installed and selected" "[ -f '$C/output-styles/terse.md' ] && [ \"\$(jq -r .outputStyle '$C/settings.json')\" = Terse ]"
check "settings merged: pin, env, 12 deny rules, user keys kept" "[ \"\$(jq -r .model '$C/settings.json')\" = claude-sonnet-5-5 ] && [ \"\$(jq -r .effortLevel '$C/settings.json')\" = medium ] && [ \"\$(jq -r '.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW' '$C/settings.json')\" = 633000 ] && [ \"\$(jq '.permissions.deny|length' '$C/settings.json')\" = 12 ] && [ \"\$(jq -r .theme '$C/settings.json')\" = dark ]"
check "CLAUDE.md has the managed block" "grep -q 'claude-code-setup:begin' '$C/CLAUDE.md' && grep -q 'claude-code-setup:end' '$C/CLAUDE.md'"
check "manifest is tab-separated" "grep -q \$'^dir\\t' '$C/.claude-code-setup.manifest' && grep -q \$'^settings\\t' '$C/.claude-code-setup.manifest'"

psrun ./install.ps1 -NoMods -Lang python >/dev/null 2>&1
check "re-run is fine and keeps one managed block" "[ \$? -eq 0 ] && [ \"\$(grep -c 'claude-code-setup:begin' '$C/CLAUDE.md')\" = 1 ]"
psrun ./install.ps1 -NoMods -Lang cobol >/dev/null 2>&1
check "unknown language is a warning, not a failure" "[ \$? -eq 0 ] && [ ! -e '$C/rules/cobol.md' ]"

psrun ./uninstall.ps1 >/dev/null 2>&1
check "uninstall.ps1 exits 0" "[ \$? -eq 0 ]"
check "skills, agents, rules, style removed" "[ ! -e '$C/skills/commit' ] && [ ! -e '$C/agents/worker.md' ] && [ ! -e '$C/rules/go.md' ] && [ ! -e '$C/skills/go-best-practices' ] && [ ! -e '$C/output-styles/terse.md' ]"
check "block, deny rules, env and style cleared; the user's settings and files kept" "! grep -q 'claude-code-setup:begin' '$C/CLAUDE.md' && [ \"\$(jq '.permissions.deny|length' '$C/settings.json')\" = 0 ] && [ \"\$(jq -r '.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW // \"none\"' '$C/settings.json')\" = none ] && [ \"\$(jq -r '.outputStyle // \"none\"' '$C/settings.json')\" = none ] && [ \"\$(jq -r .theme '$C/settings.json')\" = dark ] && [ \"\$(jq -r .model '$C/settings.json')\" = claude-sonnet-5-5 ] && [ -f '$C/mine.md' ]"

# Piped install: no checkout, a downloaded zip (a local one stands in for GitHub's).
python3 - "$ROOT/x.zip" <<'PY'
import sys, os, zipfile
z = zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED)
for d, dirs, files in os.walk('.'):
    dirs[:] = [x for x in dirs if x not in ('.git', 'node_modules')]
    for f in files:
        p = os.path.join(d, f)
        z.write(p, 'claude-code-setup-main/' + os.path.relpath(p, '.'))
z.close()
PY
CCS_ZIP="$ROOT/x.zip" "${PW[@]}" -NoProfile -Command "& ([scriptblock]::Create((Get-Content -Raw ./install.ps1))) -NoMods -Lang rust" >/dev/null 2>&1
check "piped install downloads and unpacks a copy" "[ \$? -eq 0 ] && [ -f '$CCS_HOME/.ccs-root' ] && [ -f '$C/rules/rust.md' ]"
CCS_ZIP="$ROOT/missing.zip" "${PW[@]}" -NoProfile -Command "& ([scriptblock]::Create((Get-Content -Raw ./install.ps1))) -NoMods" >/dev/null 2>&1
check "a bad download is refused" "[ \$? -ne 0 ]"
psrun "$CCS_HOME/uninstall.ps1" >/dev/null 2>&1
check "uninstall from the downloaded copy cleans up" "[ ! -e '$C/rules/rust.md' ] && [ ! -e '$C/skills/commit' ]"
exit $fail
