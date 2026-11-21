#!/usr/bin/env bash
# Installs everything into a throwaway home (no mods, so no plugin changes), checks the result, then
# uninstalls and checks that what was added is gone and what was not ours stays.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
SB="$(mktemp -d "${TMPDIR:-/tmp}/ccs.XXXXXX")"; trap 'rm -rf "$SB"' EXIT
export HOME="$SB" CLAUDE_CONFIG_DIR="$SB/.claude"; mkdir -p "$CLAUDE_CONFIG_DIR"
fail=0; check() { if eval "$2"; then printf '  ok    %s\n' "$1"; else printf '  FAIL  %s\n' "$1"; fail=1; fi; }
echo '{"theme":"dark","model":"claude-sonnet-5-5"}' > "$CLAUDE_CONFIG_DIR/settings.json"
echo "my own rule" > "$CLAUDE_CONFIG_DIR/mine.md"

./install.sh --no-mods --lang python,rust,go,cpp,ts --style terse >/dev/null 2>&1
check "installer exits 0" "[ \$? -eq 0 ]"
for l in python rust go cpp typescript; do
  check "$l rule installed with its own paths" "grep -q '^paths:' $CLAUDE_CONFIG_DIR/rules/$l.md"
  check "$l playbook skill installed" "[ -f $CLAUDE_CONFIG_DIR/skills/$l-best-practices/SKILL.md ]"
done
check "rules do not mention other languages' tools (python rule has no cargo/gofmt/clippy)" "! grep -qE 'cargo|gofmt|clippy|tsc' $CLAUDE_CONFIG_DIR/rules/python.md"
check "rust rule has no ruff/gofmt/tsc" "! grep -qE 'ruff|gofmt|tsc' $CLAUDE_CONFIG_DIR/rules/rust.md"
check "go rule has no ruff/cargo/tsc" "! grep -qE 'ruff|cargo|tsc' $CLAUDE_CONFIG_DIR/rules/go.md"
check "terse style installed and selected" "[ -f $CLAUDE_CONFIG_DIR/output-styles/terse.md ] && [ \"\$(jq -r .outputStyle $CLAUDE_CONFIG_DIR/settings.json)\" = Terse ]"
check "auto-compact and subagent cap set" "[ \"\$(jq -r '.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW' $CLAUDE_CONFIG_DIR/settings.json)\" = 633000 ]"
./install.sh --no-mods --lang python --style terse >/dev/null 2>&1
check "re-run is fine" "[ \$? -eq 0 ]"
./install.sh --no-mods --lang cobol >/dev/null 2>&1
check "unknown language is a warning, not a failure" "[ \$? -eq 0 ] && [ ! -e $CLAUDE_CONFIG_DIR/rules/cobol.md ]"

# Piped install from a downloaded tarball, with a git that fails if anything calls it (no clone, no git needed).
TAR="$SB/x.tgz"; tar czf "$TAR" --exclude=.git --transform 's,^\./,claude-code-setup-main/,' .
mkdir -p "$SB/fakebin"; printf '#!/bin/sh\necho "git must not be used" >&2; exit 99\n' > "$SB/fakebin/git"; chmod +x "$SB/fakebin/git"
./uninstall.sh >/dev/null 2>&1; rm -rf "$SB/.local"
cat install.sh | PATH="$SB/fakebin:$PATH" CCS_TARBALL="file://$TAR" bash -s -- --no-mods --lang go >/dev/null 2>&1
check "piped install from a tarball works without git" "[ \$? -eq 0 ] && [ -f $SB/.local/share/claude-code-setup/.ccs-root ] && [ ! -d $SB/.local/share/claude-code-setup/.git ]"
check "the skills point into the downloaded copy" "[ -f $CLAUDE_CONFIG_DIR/skills/go-best-practices/SKILL.md ] && readlink $CLAUDE_CONFIG_DIR/skills/commit | grep -q $SB/.local/share/claude-code-setup"
cat install.sh | PATH="$SB/fakebin:$PATH" CCS_TARBALL="file://$TAR" bash -s -- --no-mods --lang go >/dev/null 2>&1
check "re-running updates in place (one copy, no leftovers)" "[ \$? -eq 0 ] && [ \$(ls -d $SB/.local/share/claude-code-setup* | wc -l) -eq 1 ]"
check "a bad download is refused" "! (cat install.sh | CCS_TARBALL=file://$SB/nope.tgz bash -s -- --no-mods >/dev/null 2>&1)"
$SB/.local/share/claude-code-setup/uninstall.sh >/dev/null 2>&1

./uninstall.sh >/dev/null 2>&1
check "uninstall exits 0" "[ \$? -eq 0 ]"
check "rules and playbooks removed" "[ ! -e $CLAUDE_CONFIG_DIR/rules/python.md ] && [ ! -e $CLAUDE_CONFIG_DIR/skills/rust-best-practices ]"
check "terse style removed and unselected" "[ ! -e $CLAUDE_CONFIG_DIR/output-styles/terse.md ] && [ \"\$(jq -r '.outputStyle // \"none\"' $CLAUDE_CONFIG_DIR/settings.json)\" = none ]"
check "user's own settings and files kept" "[ \"\$(jq -r .theme $CLAUDE_CONFIG_DIR/settings.json)\" = dark ] && [ \"\$(jq -r .model $CLAUDE_CONFIG_DIR/settings.json)\" = claude-sonnet-5-5 ] && [ -f $CLAUDE_CONFIG_DIR/mine.md ]"

# A home folder with a space in its name (common on macOS and Windows): install, then uninstall must still clean up.
SP="$(mktemp -d "${TMPDIR:-/tmp}/ccs.XXXXXX")/Jane Smith"; mkdir -p "$SP/.claude"
( export HOME="$SP" CLAUDE_CONFIG_DIR="$SP/.claude"; ./install.sh --no-mods --lang python --style terse >/dev/null 2>&1; echo $? > "$SP/rc.install" )
check "install works when the home folder has a space" "[ \"\$(cat \"$SP/rc.install\")\" = 0 ] && [ -f \"$SP/.claude/rules/python.md\" ]"
( export HOME="$SP" CLAUDE_CONFIG_DIR="$SP/.claude"; ./uninstall.sh >/dev/null 2>&1 )
check "uninstall cleans up when the home folder has a space" "[ ! -e \"$SP/.claude/rules/python.md\" ] && [ ! -e \"$SP/.claude/output-styles/terse.md\" ] && [ ! -L \"$SP/.claude/skills/commit\" ]"
rm -rf "$(dirname "$SP")"

exit $fail
