#!/bin/bash
# Install the Drift Omarchy theme together with its rotating wallpaper fetcher.
#
#   curl -fsSL https://raw.githubusercontent.com/Pieter-Uys/omarchy-drift-theme/main/install.sh | bash
#
# Options:
#   --no-glassy   leave the bar background setting as it is
#   --no-timer    install the fetcher but don't rotate wallpapers automatically
#   --no-apply    install everything but don't switch to the theme
#   --no-recolor  keep the fixed graphite palette instead of matching the wallpaper
set -euo pipefail

REPO="https://github.com/Pieter-Uys/omarchy-drift-theme.git"
THEME_DIR="$HOME/.config/omarchy/themes/drift"
BG_DIR="$HOME/.config/omarchy/backgrounds/drift"
BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"

GLASSY=1 TIMER=1 APPLY=1 RECOLOR=1
for arg in "$@"; do
  case $arg in
    --no-glassy) GLASSY=0 ;;
    --no-timer) TIMER=0 ;;
    --no-apply) APPLY=0 ;;
    --no-recolor) RECOLOR=0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

for cmd in git curl jq omarchy; do
  command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd" >&2; exit 1; }
done

step() { printf '\e[34m::\e[0m %s\n' "$*"; }

# drift-recolor rewrites colors.toml and shell.toml in the clone. Tell git to
# leave those alone, so `git pull` and `omarchy theme update` keep working.
GENERATED=(colors.toml shell.toml)
protect_generated() { git -C "$THEME_DIR" update-index --skip-worktree "${GENERATED[@]}"; }

# 1. Theme files: a git clone, so `omarchy theme update` keeps it current.
if [[ -d $THEME_DIR/.git ]]; then
  step "Updating theme in $THEME_DIR"
  git -C "$THEME_DIR" update-index --no-skip-worktree "${GENERATED[@]}"
  git -C "$THEME_DIR" checkout -- "${GENERATED[@]}"
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
protect_generated

# 2. Commands, linked from the clone so updates come with them.
step "Linking drift-wallpaper and drift-recolor into $BIN_DIR"
mkdir -p "$BIN_DIR"
for cmd in drift-wallpaper drift-recolor; do
  chmod +x "$THEME_DIR/extras/$cmd"
  ln -sfn "$THEME_DIR/extras/$cmd" "$BIN_DIR/$cmd"
done

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

# 5. Recolour from the wallpaper whenever it changes (needs Aether).
mkdir -p "$UNIT_DIR"
if (( RECOLOR )) && ! command -v aether >/dev/null; then
  step "Installing Aether for wallpaper-matched colours"
  omarchy pkg aur add aether </dev/null || { echo "Could not install Aether; keeping the graphite palette" >&2; RECOLOR=0; }
fi
if (( RECOLOR )); then
  step "Enabling drift-recolor.path"
  cp "$THEME_DIR/extras/drift-recolor.path" "$THEME_DIR/extras/drift-recolor.service" "$UNIT_DIR/"
  systemctl --user daemon-reload
  systemctl --user enable --now drift-recolor.path
elif [[ -f $UNIT_DIR/drift-recolor.path ]]; then
  systemctl --user disable --now drift-recolor.path || true
  rm -f "$UNIT_DIR/drift-recolor.path" "$UNIT_DIR/drift-recolor.service"
  systemctl --user daemon-reload
fi

# 6. Apply.
if (( APPLY )); then
  step "Switching to Drift"
  OMARCHY_THEME_WAIT=1 omarchy theme set drift </dev/null
  if (( GLASSY )); then
    omarchy bar background glassy
  fi
  if (( RECOLOR )); then
    "$BIN_DIR/drift-recolor" --force || true
  fi
fi

step "Done. Run 'drift-wallpaper' any time for a fresh background."
