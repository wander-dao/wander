#!/usr/bin/env bash
# wander installer — downloads the prebuilt binary from GitHub Release.
# Per-user (no sudo). macOS (arm64 / x64). Windows x64: manual steps in the README.
#
# One binary does both the CLI and `wander statusline`. By default it installs
# `wander` and wires the Claude Code statusline; --no-statusline skips wiring.
#
# Usage:
#   bash install.sh                                # install wander + wire statusline (default)
#   bash install.sh --no-statusline                # install wander, don't touch settings.json
#   bash install.sh --version v0.1.0               # pin a specific release (default: latest)
#   bash install.sh --uninstall                    # remove binary (keep settings + game data)
#   bash install.sh --uninstall --clean-statusline # also strip the statusLine block from settings.json
#   bash install.sh --uninstall --purge            # also wipe archive + config (destructive, irreplaceable)
#   bash install.sh --help

set -euo pipefail

REPO="wander-dao/wander"
BIN_DIR="$HOME/.local/bin"
SETTINGS="$HOME/.claude/settings.json"
STATUSLINE_CMD="$BIN_DIR/wander statusline"
VERSION="latest"

cyan()  { printf "\033[36m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
red()   { printf "\033[31m%s\033[0m\n" "$*" >&2; }
gray()  { printf "\033[90m%s\033[0m\n" "$*"; }

# self-contained so --help works under `curl | bash` (no $0 to re-read there)
usage() {
  cat <<'EOF'
wander installer — downloads the prebuilt binary from GitHub Release.
Per-user (no sudo). macOS (arm64 / x64). Windows x64: manual steps in the README.

One binary does both the CLI and the statusline.

Usage:
  bash install.sh                                # install wander + wire statusline (default)
  bash install.sh --no-statusline                # install wander, don't touch settings.json
  bash install.sh --version v0.1.0               # pin a specific release (default: latest)
  bash install.sh --uninstall                    # remove binary (keep data + settings)
  bash install.sh --uninstall --clean-statusline # also strip the statusLine block from settings.json
  bash install.sh --uninstall --purge            # also wipe archive + config (destructive, irreplaceable)

Tip: with the CLI installed, `wander uninstall` is the richer path
(interactive, --purge-archive / --purge-config, --dry-run).
EOF
}

# ── parse args ─────────────────────────────────────────────
WIRE_STATUSLINE=1
UNINSTALL=0
CLEAN_STATUSLINE=0
PURGE_DATA=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-statusline)    WIRE_STATUSLINE=0; shift ;;
    --version)          VERSION="$2"; [[ "$VERSION" == v* || "$VERSION" == latest ]] || VERSION="v$VERSION"; shift 2 ;;
    --uninstall)        UNINSTALL=1; shift ;;
    --clean-statusline) CLEAN_STATUSLINE=1; shift ;;
    --purge)            PURGE_DATA=1; shift ;;
    -h|--help)          usage; exit 0 ;;
    *)                  red "unknown arg: $1 (try --help)"; exit 2 ;;
  esac
done

# ── platform check ─────────────────────────────────────────
OS="$(uname -s)"
if [[ "$OS" != "Darwin" ]]; then
  red "This installer supports macOS only. Detected: $OS"
  red "Windows x64 (experimental): manual install steps in the README. Linux is not supported."
  exit 1
fi
ARCH="$(uname -m)"
case "$ARCH" in
  arm64|aarch64) TARGET="aarch64-apple-darwin" ;;
  x86_64)        TARGET="x86_64-apple-darwin" ;;
  *)             red "unsupported arch: $ARCH (need arm64 or x86_64)"; exit 1 ;;
esac

# ── JSON helpers (jq if available, fall back to python3) ───
have_jq() { command -v jq >/dev/null 2>&1; }
have_py() { command -v python3 >/dev/null 2>&1; }

json_get() { # $1=file $2=jq-path
  local file="$1" path="$2"
  if have_jq; then
    jq -r "$path // empty" "$file" 2>/dev/null
  elif have_py; then
    python3 - "$file" "$path" <<'PY' 2>/dev/null
import json, sys
file, path = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(file))
except Exception:
    sys.exit(0)
for k in [s for s in path.lstrip('.').split('.') if s]:
    if isinstance(d, dict) and k in d:
        d = d[k]
    else:
        sys.exit(0)
if d is not None and not isinstance(d, (dict, list)):
    print(d)
PY
  fi
}

json_validate() { # $1=file
  if have_jq; then jq empty "$1" >/dev/null 2>&1
  elif have_py; then python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" >/dev/null 2>&1
  else return 0; fi
}

backup_settings() {
  if [[ -f "$SETTINGS" ]]; then
    local backup="${SETTINGS}.bak.$(date +%s)"
    cp "$SETTINGS" "$backup"
    echo "$backup"
  fi
}

patch_settings() {
  if ! have_jq && ! have_py; then
    red "no jq or python3 found — can't safely edit JSON. Falling back to print mode."
    print_settings_hint
    return
  fi

  mkdir -p "$(dirname "$SETTINGS")"
  if [[ ! -f "$SETTINGS" ]]; then
    echo '{}' > "$SETTINGS"
    gray "created $SETTINGS"
  elif ! json_validate "$SETTINGS"; then
    red "$SETTINGS is not valid JSON — refusing to touch. Fix it first, then re-run."
    return 1
  fi

  local existing
  existing="$(json_get "$SETTINGS" '.statusLine.command')"
  if [[ -n "$existing" && "$existing" != "$STATUSLINE_CMD" ]]; then
    red "⚠  settings.json already has a statusLine.command:"
    red "    $existing"
    printf "   Overwrite with 'wander statusline'? [y/N] "
    # /dev/tty: under `curl | bash` stdin is the script itself — reading it would eat script lines
    read -r ans < /dev/tty || ans=""
    if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
      gray "skipped settings.json patch"
      return
    fi
  elif [[ "$existing" == "$STATUSLINE_CMD" ]]; then
    gray "settings.json already wired to wander statusline (no change)"
    return
  fi

  local backup tmp="${SETTINGS}.tmp"
  backup="$(backup_settings)" || true

  if have_jq; then
    jq --arg cmd "$STATUSLINE_CMD" \
       '.statusLine = {type:"command", command:$cmd}' \
       "$SETTINGS" > "$tmp"
  else
    python3 - "$SETTINGS" "$STATUSLINE_CMD" > "$tmp" <<'PY'
import json, sys
file, cmd = sys.argv[1], sys.argv[2]
d = json.load(open(file))
d["statusLine"] = {"type": "command", "command": cmd}
print(json.dumps(d, indent=2, ensure_ascii=False))
PY
  fi

  if ! json_validate "$tmp"; then
    red "patched JSON invalid, abort (original untouched${backup:+, backup at $backup})"
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$SETTINGS"
  green "patched $SETTINGS"
  [[ -n "$backup" ]] && gray "  backup: $backup"
}

unpatch_settings() {
  [[ -f "$SETTINGS" ]] || { gray "no $SETTINGS — nothing to clean"; return; }
  if ! have_jq && ! have_py; then
    red "no jq or python3 — can't safely edit JSON. Manually remove statusLine from $SETTINGS."
    return
  fi
  if ! json_validate "$SETTINGS"; then
    red "$SETTINGS not valid JSON — refusing to touch."
    return
  fi

  local existing
  existing="$(json_get "$SETTINGS" '.statusLine.command')"
  if [[ -z "$existing" ]]; then
    gray "settings.json has no statusLine — already clean"
    return
  fi
  if [[ "$existing" != "$STATUSLINE_CMD" ]]; then
    red "⚠  settings.json statusLine is not wander's:"
    red "    $existing"
    gray "leaving it untouched."
    return
  fi

  local backup tmp="${SETTINGS}.tmp"
  backup="$(backup_settings)" || true

  if have_jq; then
    jq 'del(.statusLine)' "$SETTINGS" > "$tmp"
  else
    python3 - "$SETTINGS" > "$tmp" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d.pop("statusLine", None)
print(json.dumps(d, indent=2, ensure_ascii=False))
PY
  fi

  if ! json_validate "$tmp"; then
    red "edited JSON invalid, abort (original untouched${backup:+, backup at $backup})"
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$SETTINGS"
  green "removed statusLine from $SETTINGS"
  [[ -n "$backup" ]] && gray "  backup: $backup"
}

print_settings_hint() {
  echo "   Edit $SETTINGS and add:"
  cat <<EOF
   {
     "statusLine": {
       "type": "command",
       "command": "$STATUSLINE_CMD"
     }
   }
EOF
}

# ── download helper ────────────────────────────────────────
download() { # $1=asset $2=output
  local asset="$1" out="$2" url
  # GitHub asset URL shapes differ: latest/download/<asset> vs download/<tag>/<asset>
  if [[ "$VERSION" == "latest" ]]; then
    url="https://github.com/$REPO/releases/latest/download/$asset"
  else
    url="https://github.com/$REPO/releases/download/$VERSION/$asset"
  fi
  # silent download: --progress-bar redraws over itself on the release-asset
  # 302 redirect (two responses, one line) and smears garbage on some terminals;
  # the ▶ line above is the user feedback. -sS still surfaces real errors.
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$out" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$out" "$url"
  else
    red "need curl or wget to download"; exit 1
  fi
}

# ── uninstall path ─────────────────────────────────────────
if (( UNINSTALL )); then
  if [[ -f "$BIN_DIR/wander" ]]; then
    rm "$BIN_DIR/wander"
    green "removed $BIN_DIR/wander"
  else
    gray "not present: $BIN_DIR/wander"
  fi

  # cache is always removed (regenerable); archive + config only with --purge.
  CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wander"
  if [[ -d "$CACHE_DIR" ]]; then
    rm -rf "$CACHE_DIR"
    green "removed $CACHE_DIR"
  fi

  if (( PURGE_DATA )); then
    for d in "${XDG_DATA_HOME:-$HOME/.local/share}/wander" "${XDG_CONFIG_HOME:-$HOME/.config}/wander"; do
      if [[ -d "$d" ]]; then
        rm -rf "$d"
        red "purged $d"
      fi
    done
  else
    gray "(archive + config preserved — pass --purge to wipe them)"
  fi

  if (( CLEAN_STATUSLINE )); then
    unpatch_settings
  else
    gray "(settings.json untouched — pass --clean-statusline to remove the statusLine entry)"
  fi

  echo
  cyan "Done. wander removed."
  if (( ! PURGE_DATA )); then
    gray "Archive + config preserved (~/.local/share/wander, ~/.config/wander) — re-install anytime."
  fi
  exit 0
fi

# ── install path ───────────────────────────────────────────
mkdir -p "$BIN_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cyan "▶ downloading wander ($TARGET)…"
download "wander-$TARGET.tar.gz" "$tmp/wander.tar.gz"
tar -xzf "$tmp/wander.tar.gz" -C "$tmp"
mv "$tmp/wander" "$BIN_DIR/wander"
chmod +x "$BIN_DIR/wander"
# Strip Gatekeeper quarantine so the unsigned binary runs without a warning.
xattr -d com.apple.quarantine "$BIN_DIR/wander" 2>/dev/null || true
green "installed $BIN_DIR/wander"

# ── PATH check ─────────────────────────────────────────────
case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *)
    echo
    red "⚠  $BIN_DIR is not in your PATH."
    echo "   Add to ~/.zshrc and re-source:"
    echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

# ── wire Claude Code statusline ────────────────────────────
if (( WIRE_STATUSLINE )); then
  echo
  cyan "▶ wiring Claude Code statusline…"
  patch_settings
fi

# ── done ───────────────────────────────────────────────────
echo
green "✔ Done."
if (( WIRE_STATUSLINE )); then
  echo "   Open Claude Code — your status bar now shows your 修行 state."
fi
echo "   Try:"
echo "      wander stats          # 修行 panorama"
echo "      wander bag            # 行囊 (修為 / 靈氣 / 靈石)"
echo "      wander cultivate      # 煉化 pool 靈氣 → 修為"
echo "      wander --help         # all subcommands"
