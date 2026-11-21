#!/usr/bin/env bash
# Removes what install.sh added: skill links, agent files, the CLAUDE.md block, our settings entries, our plugins.
set -euo pipefail
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MANIFEST="$CLAUDE_DIR/.claude-code-setup.manifest"
BEGIN='<!-- claude-code-setup:begin -->'; END='<!-- claude-code-setup:end -->'
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "${CCS_HOME:-$HOME/.local/share/claude-code-setup}")"
say() { printf '\033[36m==>\033[0m %s\n' "$*"; }
[ -f "$MANIFEST" ] || { echo "Nothing recorded at $MANIFEST; nothing to remove."; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
while read -r kind path rest; do
  case "$kind" in
    symlink) [ -L "$path" ] && { rm "$path"; echo "    removed $path"; } ;;
    file)    [ -f "$path" ] && grep -q 'managed by claude-code-setup' "$path" && { rm "$path"; echo "    removed $path"; } ;;
    block)   [ -f "$path" ] && { tmp="$(mktemp)"; awk -v b="$BEGIN" -v e="$END" '$0==b{s=1} !s{print} $0==e{s=0}' "$path" > "$tmp" && mv "$tmp" "$path"; echo "    removed instructions block from $path"; } ;;
    settings)
      base="$HERE/settings/settings.base.json"
      if [ -f "$path" ] && [ -f "$base" ]; then
        jq --slurpfile b "$base" '
          ($b[0]) as $b
          | .permissions.deny = ((.permissions.deny // []) - ($b.permissions.deny // []))
          | (if .env.CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS == $b.env.CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS then del(.env.CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS) else . end)
          | (if .env.CLAUDE_CODE_AUTO_COMPACT_WINDOW == $b.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW then del(.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW) else . end)
          | (if $keepm == 0 and .model == $b.model then del(.model) else . end)
          | (if $keepe == 0 and .effortLevel == $b.effortLevel then del(.effortLevel) else . end)' --argjson keepm "$([[ " $rest " == *"had_model=1"* ]] && echo 1 || echo 0)" --argjson keepe "$([[ " $rest " == *"had_effort=1"* ]] && echo 1 || echo 0)" "$path" > "$path.new" && mv "$path.new" "$path"
        echo "    removed our entries from $path (your other settings are untouched)"
      fi ;;
    plugin) command -v claude >/dev/null 2>&1 && claude plugin uninstall "$path" >/dev/null 2>&1 && echo "    uninstalled plugin $path" || true ;;
  esac
done < "$MANIFEST"
rm -f "$MANIFEST"
say "Done. Backups made by the installer are in $CLAUDE_DIR/backups/ if you want to restore anything."
