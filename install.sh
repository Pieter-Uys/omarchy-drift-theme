#!/bin/bash
# Install the Drift Omarchy theme together with its rotating wallpaper fetcher.
#
#   curl -fsSL https://raw.githubusercontent.com/Pieter-Uys/omarchy-drift-theme/main/install.sh | bash
#
# Options:
#   --no-glassy   leave the bar background setting as it is
#   --no-timer    install the fetcher but don't rotate wallpapers automatically
#   --no-apply    install everything but don't switch to the theme
set -euo pipefail

REPO="https://github.com/Pieter-Uys/omarchy-drift-theme.git"
THEME_DIR="$HOME/.config/omarchy/themes/drift"
BG_DIR="$HOME/.config/omarchy/backgrounds/drift"
BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"

GLASSY=1 TIMER=1 APPLY=1
for arg in "$@"; do
  case $arg in
    --no-glassy) GLASSY=0 ;;
    --no-timer) TIMER=0 ;;
    --no-apply) APPLY=0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

for cmd in git curl jq omarchy; do
  command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd" >&2; exit 1; }
done

step() { printf '\e[34m::\e[0m %s\n' "$*"; }

# 1. Theme files: a git clone, so `omarchy theme update` keeps it current.
if [[ -d $THEME_DIR/.git ]]; then
  step "Updating theme in $THEME_DIR"
  git -C "$THEME_DIR" pull --ff-only
else
  if [[ -e $THEME_DIR ]]; then
    backup="$HOME/.local/share/omarchy-drift-backup-$(date +%s)"
    step "Backing up existing $THEME_DIR to $backup"
    mkdir -p "${backup%/*}"
    mv "$THEME_DIR" "$backup"
  fi
  step "Cloning theme into $THEME_DIR"
  git clone --depth 1 -- "$REPO" "$THEME_DIR"
fi

# 2. Wallpaper fetcher, linked from the clone so updates come with it.
step "Linking drift-wallpaper into $BIN_DIR"
mkdir -p "$BIN_DIR"
chmod +x "$THEME_DIR/extras/drift-wallpaper"
ln -sfn "$THEME_DIR/extras/drift-wallpaper" "$BIN_DIR/drift-wallpaper"

# 3. Seed a few wallpapers so the theme has something to show right away.
mkdir -p "$BG_DIR"
have=$(find "$BG_DIR" -maxdepth 1 -type f -name 'wallhaven-*' | wc -l)
if (( have < 4 )); then
  step "Downloading starter wallpapers"
  for _ in $(seq $((4 - have))); do
    "$BIN_DIR/drift-wallpaper" --no-apply || true
    sleep 1
  done
fi

# 4. Timer that rotates the wallpaper every two hours.
if (( TIMER )); then
  step "Enabling drift-wallpaper.timer"
  mkdir -p "$UNIT_DIR"
  cp "$THEME_DIR/extras/drift-wallpaper.service" "$THEME_DIR/extras/drift-wallpaper.timer" "$UNIT_DIR/"
  systemctl --user daemon-reload
  systemctl --user enable --now drift-wallpaper.timer
fi

# 5. Apply.
if (( APPLY )); then
  step "Switching to Drift"
  OMARCHY_THEME_WAIT=1 omarchy theme set drift </dev/null
  if (( GLASSY )); then
    omarchy bar background glassy
  fi
fi

step "Done. Run 'drift-wallpaper' any time for a fresh background."
