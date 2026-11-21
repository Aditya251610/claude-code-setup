#!/usr/bin/env bash
# claude-code-setup installer.
#   curl -fsSL https://raw.githubusercontent.com/Aditya251610/claude-code-setup/main/install.sh | bash
#   or: git clone ... && ./install.sh [--dry-run]
# Safe to re-run. Backs up anything it replaces. Never uses sudo.
set -euo pipefail

REPO_URL="${CCS_REPO:-https://github.com/Aditya251610/claude-code-setup}"
DEST="${CCS_HOME:-$HOME/.local/share/claude-code-setup}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MANIFEST="$CLAUDE_DIR/.claude-code-setup.manifest"
BEGIN='<!-- claude-code-setup:begin -->'
END='<!-- claude-code-setup:end -->'
MARK='managed by claude-code-setup'
DRY=0; PIN=1; MODS=1; LSP=""

usage() { cat <<'U'
Usage: install.sh [options]
  --dry-run          show what would change, change nothing
  --no-model-pin     do not set the default model / effort in settings.json
  --no-mods          skip installing the mods (plugins)
  --lsp LIST         also set up language-server plugins: python,rust,cpp,go (prints the
                     system commands for the servers; never runs sudo)
  -h, --help
U
}
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;; --no-model-pin) PIN=0 ;; --no-mods) MODS=0 ;;
    --lsp) LSP="${2:-}"; shift ;; -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac; shift
done

say()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[31mxx\033[0m  %s\n' "$*" >&2; exit 1; }
act()  { if [ "$DRY" = 1 ]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }

# ── Environment ──────────────────────────────────────────────────────────
case "$(uname -s)" in
  Linux)  OS=linux; grep -qi microsoft /proc/version 2>/dev/null && OS=wsl ;;
  Darwin) OS=macos ;;
  *) die "Unsupported OS: $(uname -s). Linux, macOS and WSL are supported." ;;
esac
PM=""
for p in brew pacman apt-get dnf zypper; do command -v "$p" >/dev/null 2>&1 && { PM=$p; break; }; done
say "System: $OS${PM:+ (package manager: $PM)}"
command -v jq >/dev/null 2>&1 || die "jq is required. Install it first (e.g. 'brew install jq', 'sudo pacman -S jq', 'sudo apt install jq')."

# ── Source: this clone, or fetch one ─────────────────────────────────────
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$HERE" ] && [ -f "$HERE/.ccs-root" ]; then
  SRC="$HERE"
else
  command -v git >/dev/null 2>&1 || die "git is required to download claude-code-setup."
  SRC="$DEST"
  if [ -d "$DEST/.git" ]; then say "Updating $DEST"; act git -C "$DEST" pull -q --ff-only
  else say "Downloading to $DEST"; act git clone -q --depth 1 "$REPO_URL" "$DEST"; fi
  if [ "$DRY" = 1 ] && [ ! -f "$SRC/.ccs-root" ]; then say "(dry run: nothing downloaded, so the file list below is not shown)"; exit 0; fi
fi
[ -f "$SRC/.ccs-root" ] || die "Not a claude-code-setup checkout: $SRC"

# ── Backups and manifest ─────────────────────────────────────────────────
BK="$CLAUDE_DIR/backups/claude-code-setup-$(date +%Y%m%d-%H%M%S)"
backup() { local p="$1"; { [ -e "$p" ] || [ -L "$p" ]; } || return 0
  act mkdir -p "$BK/$(dirname "${p#"$CLAUDE_DIR"/}")"; act cp -a "$p" "$BK/${p#"$CLAUDE_DIR"/}"; }
record() { [ "$DRY" = 1 ] && return 0; mkdir -p "$CLAUDE_DIR"; printf '%s\n' "$*" >> "$MANIFEST"; }
[ "$DRY" = 1 ] || { mkdir -p "$CLAUDE_DIR"; : > "$MANIFEST"; }   # rebuilt on every run

# ── Skills: symlinks (so `git pull` updates them) ────────────────────────
say "Skills -> $CLAUDE_DIR/skills"
act mkdir -p "$CLAUDE_DIR/skills"
for d in "$SRC"/skills/*/; do
  n="$(basename "$d")"; t="$CLAUDE_DIR/skills/$n"
  if [ -L "$t" ] && [ "$(readlink "$t")" = "${d%/}" ]; then echo "    ok      $n"
  elif [ -L "$t" ] && case "$(readlink "$t")" in */claude-code-setup/*|"$SRC"/*) true;; *) false;; esac; then
    act ln -sfn "${d%/}" "$t"; echo "    relink  $n"
  elif [ -e "$t" ] || [ -L "$t" ]; then warn "skill '$n' already exists and is not ours; left alone"; continue
  else act ln -s "${d%/}" "$t"; echo "    link    $n"; fi
  record "symlink $t"
done

# ── Agents: copies (symlinks for agents are not documented) ──────────────
say "Agents -> $CLAUDE_DIR/agents"
act mkdir -p "$CLAUDE_DIR/agents"
for f in "$SRC"/agents/*.md; do
  n="$(basename "$f")"; t="$CLAUDE_DIR/agents/$n"
  if [ -e "$t" ] && ! grep -q "$MARK" "$t"; then warn "agent '$n' already exists and is not ours; left alone"; continue; fi
  if [ -e "$t" ] && cmp -s "$f" "$t"; then echo "    ok      $n"; else backup "$t"; act cp "$f" "$t"; echo "    copy    $n"; fi
  record "file $t"
done

# ── CLAUDE.md: a managed block, the rest of the file is untouched ────────
say "Instructions -> $CLAUDE_DIR/CLAUDE.md (managed block)"
CM="$CLAUDE_DIR/CLAUDE.md"
if [ "$DRY" = 1 ]; then echo "    [dry-run] insert/replace the block between $BEGIN and $END"
else
  backup "$CM"; touch "$CM"
  tmp="$(mktemp)"
  awk -v b="$BEGIN" -v e="$END" '$0==b{skip=1} !skip{print} $0==e{skip=0}' "$CM" > "$tmp"
  { cat "$tmp"; [ -s "$tmp" ] && echo; echo "$BEGIN"; cat "$SRC/CLAUDE.md"; echo "$END"; } > "$CM"
  rm -f "$tmp"
  record "block $CM"
fi

# ── settings.json: merged, never replaced ────────────────────────────────
say "Settings -> $CLAUDE_DIR/settings.json (merge)"
SJ="$CLAUDE_DIR/settings.json"
JQ='def uniq: reduce .[] as $x ([]; if index($x) then . else . + [$x] end);
  .[0] as $u | .[1] as $b | $u
  | (if $pin == 1 then .model = $b.model | .effortLevel = $b.effortLevel else . end)
  | .env = (($b.env // {}) + (.env // {}))
  | .permissions = ((.permissions // {}) | .deny = (((.deny // []) + ($b.permissions.deny // [])) | uniq))'
if [ "$DRY" = 1 ]; then
  echo "    [dry-run] merge $SRC/settings/settings.base.json (model pin: $([ $PIN = 1 ] && echo yes || echo no))"
  if [ -f "$SJ" ]; then
    mt="$(mktemp)"; jq -s --argjson pin "$PIN" "$JQ" "$SJ" "$SRC/settings/settings.base.json" > "$mt"
    diff <(jq -S . "$SJ") <(jq -S . "$mt") | sed 's/^/    /' || true; rm -f "$mt"
  fi
else
  [ -f "$SJ" ] || echo '{}' > "$SJ"
  jq -e . "$SJ" >/dev/null 2>&1 || die "$SJ is not valid JSON; fix it and re-run (nothing was changed in it)."
  backup "$SJ"
  jq -s --argjson pin "$PIN" "$JQ" "$SJ" "$SRC/settings/settings.base.json" > "$SJ.new" && mv "$SJ.new" "$SJ"
  record "settings $SJ pin=$PIN"
fi

# ── Mods (plugins) ───────────────────────────────────────────────────────
if [ "$MODS" = 1 ] && [ -f "$SRC/.claude-plugin/marketplace.json" ]; then
  say "Mods"
  if command -v claude >/dev/null 2>&1; then
    act claude plugin marketplace add "$SRC" || warn "could not add the marketplace (already added?)"
    for m in $(jq -r '.plugins[].name' "$SRC/.claude-plugin/marketplace.json"); do
      act claude plugin install "$m@claude-code-setup" --scope user && record "plugin $m@claude-code-setup" || warn "could not install mod $m"
    done
  else warn "'claude' not found on PATH; skipped mods. Re-run after installing Claude Code."; fi
fi

# ── Language servers (opt-in) ────────────────────────────────────────────
if [ -n "$LSP" ]; then
  say "Language servers: $LSP"
  IFS=',' read -ra LANGS <<< "$LSP"
  for l in "${LANGS[@]}"; do
    case "$l" in
      python) plug=pyright-lsp;       cmd="pip install --user pyright   (or: npm i -g pyright)" ;;
      rust)   plug=rust-analyzer-lsp; cmd="rustup component add rust-analyzer" ;;
      cpp)    plug=clangd-lsp;        case "$PM" in pacman) cmd="sudo pacman -S clang";; apt-get) cmd="sudo apt install clangd";; dnf) cmd="sudo dnf install clang-tools-extra";; brew) cmd="brew install llvm";; *) cmd="install clangd with your package manager";; esac ;;
      go)     plug=gopls-lsp;         cmd="go install golang.org/x/tools/gopls@latest" ;;
      *) warn "unknown language '$l'"; continue ;;
    esac
    command -v claude >/dev/null 2>&1 && { act claude plugin install "$plug@claude-plugins-official" --scope user && record "plugin $plug@claude-plugins-official" || warn "could not install $plug"; }
    echo "    server for $l (run yourself): $cmd"
  done
fi

say "Done.$([ "$DRY" = 1 ] && echo ' (dry run, nothing was changed)') Backups, if any: $BK"
say "Restart Claude Code, then check '/plugin' and '/agents'. Remove everything with ./uninstall.sh"
