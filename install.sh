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
DRY=0; PIN=1; MODS=1; LSP=""; PACKS=""; STYLE=""

usage() { cat <<'U'
Usage: install.sh [options]
  --dry-run          show what would change, change nothing
  --no-model-pin     do not set the default model / effort in settings.json
  --no-mods          skip installing the mods (plugins)
  --lang LIST        install language rules (python,rust,go,cpp,ts): short defaults that load
                     only when matching files are touched; prints what toolchain is missing
  --style NAME       install and select an output style (terse: short bullets, no recap)
  --lsp LIST         also set up language-server plugins: python,rust,cpp,go,ts (prints the
                     system commands for the servers; never runs sudo)
  -h, --help
U
}
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;; --no-model-pin) PIN=0 ;; --no-mods) MODS=0 ;;
    --lang) PACKS="${2:-}"; shift ;; --style) STYLE="${2:-}"; shift ;;
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
HERE=""
# Only trust the script's own folder when run from a file; when piped (curl | bash) there is none.
[ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ] && HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
# New entries go to a side file and are merged into the manifest when the run ends, however it ends.
NEWM="$MANIFEST.new"
record() { [ "$DRY" = 1 ] && return 0; printf '%s\n' "$*" >> "$NEWM"; }
# The manifest only ever grows: a run with other options (or one that fails) must not forget what an
# earlier run installed. The earliest line per kind+path wins, so the first record of the user's own
# settings (what they had before us) is never overwritten. Uninstall skips anything already gone.
finish_manifest() { [ -f "$NEWM" ] || return 0
  { [ -f "$MANIFEST" ] && cat "$MANIFEST"; cat "$NEWM"; } | awk '!seen[$1" "$2]++' > "$MANIFEST.tmp" && mv "$MANIFEST.tmp" "$MANIFEST"; rm -f "$NEWM"; }
[ "$DRY" = 1 ] || { mkdir -p "$CLAUDE_DIR"; : > "$NEWM"; trap finish_manifest EXIT; }

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

# ── Languages (opt-in): each language is self-contained, so they never mix ──
#   rule  -> ~/.claude/rules/<lang>.md       short guardrails, auto-loaded only when matching files are touched
#   skill -> ~/.claude/skills/<lang>-best-practices   a fuller playbook, loaded only when you ask about that language
if [ -n "$PACKS" ]; then
  say "Languages -> $CLAUDE_DIR/rules and $CLAUDE_DIR/skills ($PACKS)"
  act mkdir -p "$CLAUDE_DIR/rules" "$CLAUDE_DIR/skills"
  have() { command -v "$1" >/dev/null 2>&1; }
  sys() { case "$PM" in pacman) echo "sudo pacman -S $1";; apt-get) echo "sudo apt install $2";; dnf) echo "sudo dnf install $3";; brew) echo "brew install $4";; *) echo "install $4 with your package manager";; esac; }
  IFS=',' read -ra WANT <<< "$PACKS"
  for l in "${WANT[@]}"; do
    case "$l" in ts) l=typescript ;; c|c++) l=cpp ;; esac
    case "$l" in python|rust|go|cpp|typescript) ;; *) warn "unknown language '$l' (use python, rust, go, cpp, ts)"; continue ;; esac
    t="$CLAUDE_DIR/rules/$l.md"
    if [ -e "$t" ] && ! grep -q "$MARK" "$t"; then warn "rule '$l.md' already exists and is not ours; left alone"
    else
      if [ -e "$t" ] && cmp -s "$SRC/langs/$l/rule.md" "$t"; then echo "    ok      rule  $l"; else backup "$t"; act cp "$SRC/langs/$l/rule.md" "$t"; echo "    copy    rule  $l"; fi
      record "file $t"
    fi
    sk="$CLAUDE_DIR/skills/$l-best-practices"; src="$SRC/langs/$l/skill"
    if [ -L "$sk" ] && [ "$(readlink "$sk")" = "$src" ]; then echo "    ok      skill $l-best-practices"; record "symlink $sk"
    elif [ -e "$sk" ] || [ -L "$sk" ]; then warn "skill '$l-best-practices' already exists and is not ours; left alone"
    else act ln -s "$src" "$sk"; echo "    link    skill $l-best-practices"; record "symlink $sk"; fi
    case "$l" in
      python) have python3 || echo "    missing: python3 ($(sys python python3 python3 python))"
              have ruff   || echo "    missing: ruff    (uv tool install ruff   or: pip install --user ruff)"
              have pytest || echo "    missing: pytest  (uv tool install pytest   or: pip install --user pytest)" ;;
      rust)   have cargo  || echo "    missing: Rust toolchain (install rustup from https://rustup.rs, then: rustup component add clippy rustfmt rust-analyzer)" ;;
      go)     have go     || echo "    missing: go      ($(sys go golang-go golang go))" ;;
      cpp)    have g++ || have clang++ || echo "    missing: C++ compiler ($(sys gcc g++ gcc-c++ gcc))"
              have cmake  || echo "    missing: cmake   ($(sys cmake cmake cmake cmake))" ;;
      typescript) have node || echo "    missing: node    ($(sys nodejs nodejs nodejs node))"
              have tsc    || echo "    missing: tsc     (npm i -g typescript, or add typescript to the project)" ;;
    esac
  done
fi

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
  # Remember whether you already had a model / effort setting, so uninstall never deletes your own choice.
  # The first run decides: later runs reuse that record (by then our pin is in the file).
  OLD_SET="$(grep "^settings $SJ " "$MANIFEST" 2>/dev/null | head -1 || true)"
  if [ -n "$OLD_SET" ]; then HAD="$(printf '%s' "$OLD_SET" | grep -o 'had_model=[01] had_effort=[01]' || true)"
  else HAD="had_model=$(jq -r 'if has("model") then 1 else 0 end' "$SJ") had_effort=$(jq -r 'if has("effortLevel") then 1 else 0 end' "$SJ")"; fi
  jq -s --argjson pin "$PIN" "$JQ" "$SJ" "$SRC/settings/settings.base.json" > "$SJ.new" && mv "$SJ.new" "$SJ"
  record "settings $SJ pin=$PIN ${HAD:-}"
fi

# ── Output style (opt-in) ────────────────────────────────────────────────
if [ -n "$STYLE" ]; then
  case "$STYLE" in
    terse)
      say "Output style -> $CLAUDE_DIR/output-styles/terse.md"
      t="$CLAUDE_DIR/output-styles/terse.md"
      act mkdir -p "$CLAUDE_DIR/output-styles"
      if [ -e "$t" ] && ! grep -q "$MARK" "$t"; then warn "output style 'terse' already exists and is not ours; left alone"
      else
        if [ -e "$t" ] && cmp -s "$SRC/output-styles/terse.md" "$t"; then echo "    ok      terse.md"; else backup "$t"; act cp "$SRC/output-styles/terse.md" "$t"; echo "    copy    terse.md"; fi
        record "file $t"
        if [ "$DRY" = 1 ]; then echo "    [dry-run] select it as the default (outputStyle) unless you already chose one"
        elif [ "$(jq -r 'has("outputStyle")' "$SJ")" = "false" ]; then
          jq '.outputStyle = "Terse"' "$SJ" > "$SJ.new" && mv "$SJ.new" "$SJ"; record "outputstyle $SJ"; echo "    selected as your default style (change it any time with /output-style)"
        else echo "    you already have an output style set; left it. Switch with /output-style"; fi
      fi ;;
    *) warn "unknown style '$STYLE' (available: terse)" ;;
  esac
fi

# ── Mods (plugins) ───────────────────────────────────────────────────────
if [ "$MODS" = 1 ] && [ -f "$SRC/.claude-plugin/marketplace.json" ]; then
  say "Mods"
  if command -v claude >/dev/null 2>&1; then
    act claude plugin marketplace add "$SRC" || warn "could not add the marketplace (already added?)"
    for m in $(jq -r '.plugins[].name' "$SRC/.claude-plugin/marketplace.json"); do
      act claude plugin install "$m@claude-code-setup" --scope user && record "plugin $m@claude-code-setup" || warn "could not install mod $m"
    done
    # Mods this setup used to ship and no longer does: remove them if an earlier version installed them.
    for old in token-weather; do
      if [ "$DRY" = 1 ]; then echo "    [dry-run] claude plugin uninstall $old@claude-code-setup (only if installed)"
      else claude plugin uninstall "$old@claude-code-setup" --scope user >/dev/null 2>&1 && echo "    removed retired mod $old" || true; fi
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
      ts)     plug=typescript-lsp;    cmd="npm i -g typescript typescript-language-server" ;;
      *) warn "unknown language '$l'"; continue ;;
    esac
    command -v claude >/dev/null 2>&1 && { act claude plugin install "$plug@claude-plugins-official" --scope user && record "plugin $plug@claude-plugins-official" || warn "could not install $plug"; }
    echo "    server for $l (run yourself): $cmd"
  done
fi

say "Done.$([ "$DRY" = 1 ] && echo ' (dry run, nothing was changed)') Backups, if any: $BK"
say "Restart Claude Code, then check '/plugin' and '/agents'. Remove everything with ./uninstall.sh"
