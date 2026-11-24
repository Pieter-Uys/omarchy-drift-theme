#!/bin/bash
# Install the Drift Omarchy theme together with its rotating wallpaper fetcher.
#
#   curl -fsSL https://raw.githubusercontent.com/Pieter-Uys/omarchy-drift-theme/main/install.sh | bash
#
# Options:
#   --no-glassy   leave the bar background setting as it is
#   --timer       also rotate the wallpaper every two hours (off unless asked for;
#                 an existing timer is kept on re-install)
#   --no-timer    remove the rotation timer (drift-wallpaper still works by hand)
#   --no-apply    install everything but don't switch to the theme
#   --no-recolor  keep the fixed graphite palette instead of matching the wallpaper
#   --uninstall   remove Drift, its commands, units, state and downloaded wallpapers
#                 (switches back to the theme that was active before Drift)
set -euo pipefail

REPO="https://github.com/Pieter-Uys/omarchy-drift-theme.git"
THEME_DIR="$HOME/.config/omarchy/themes/drift"
BG_DIR="$HOME/.config/omarchy/backgrounds/drift"
BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"
STATE="$HOME/.local/state/omarchy"
STARTER=4  # wallpapers to have on disk before the first switch

GLASSY=1 TIMER=keep APPLY=1 RECOLOR=1 UNINSTALL=0
for arg in "$@"; do
  case $arg in
    --no-glassy) GLASSY=0 ;;
    --timer) TIMER=1 ;;
    --no-timer) TIMER=0 ;;
    --no-apply) APPLY=0 ;;
    --no-recolor) RECOLOR=0 ;;
    --uninstall) UNINSTALL=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

step() { printf '\e[34m::\e[0m %s\n' "$*"; }

# enable_units <name> <kind>: install <name>.service and <name>.<kind> from the
# clone and start <name>.<kind>.
enable_units() {
  cp "$THEME_DIR/extras/$1.service" "$THEME_DIR/extras/$1.$2" "$UNIT_DIR/"
  systemctl --user daemon-reload
  systemctl --user enable --now "$1.$2"
}

# disable_units <name> <kind>: stop <name>.<kind> and remove both unit files.
disable_units() {
  systemctl --user disable --now "$1.$2" || true
  rm -f "$UNIT_DIR/$1.$2" "$UNIT_DIR/$1.service"
  systemctl --user daemon-reload
}

# Undo everything install.sh did. Safe to re-run, and works when the theme was
# already removed with `omarchy theme remove drift`.
uninstall() {
  local unit cmd prev dir
  # Units first, so switching themes below cannot set off a recolour.
  for unit in drift-wallpaper.timer drift-recolor.path; do
    if [[ -f $UNIT_DIR/$unit ]]; then
      step "Removing $unit"
      disable_units "${unit%.*}" "${unit##*.}"
    fi
  done

  if [[ $(cat "$STATE/current/theme.name" 2>/dev/null) == "drift" ]]; then
    prev=$(cat "$STATE/drift-previous-theme" 2>/dev/null || true)
    if [[ -z $prev || ! ( -d $HOME/.config/omarchy/themes/$prev || -d ${OMARCHY_PATH:-/usr/share/omarchy}/themes/$prev ) ]]; then
      prev=matte-black
    fi
    step "Switching back to $prev"
    OMARCHY_THEME_WAIT=1 omarchy theme set "$prev" </dev/null
  fi

  # Only our own links: never a drift-* command the user put there themselves.
  for cmd in drift-wallpaper drift-recolor; do
    if [[ -L $BIN_DIR/$cmd && $(readlink "$BIN_DIR/$cmd") == "$THEME_DIR/"* ]]; then
      step "Removing $BIN_DIR/$cmd"
      rm -f "$BIN_DIR/$cmd"
    fi
  done

  rm -f "$STATE/drift-recolor.last" "$STATE/drift-previous-theme"
  for dir in "$THEME_DIR" "$BG_DIR"; do
    if [[ -e $dir ]]; then
      step "Removing $dir"
      rm -rf "$dir"
    fi
  done
  step "Drift is uninstalled."
}

if (( UNINSTALL )); then
  uninstall
  exit 0
fi

for cmd in git curl jq omarchy; do
  command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd" >&2; exit 1; }
done

# drift-recolor rewrites colors.toml and shell.toml in the clone. Tell git to
# leave those alone, so `git pull` and `omarchy theme update` keep working.
GENERATED=(colors.toml shell.toml)

# 1. Theme files: a git clone, so `omarchy theme update` keeps it current.
if [[ -d $THEME_DIR/.git ]]; then
  step "Updating theme in $THEME_DIR"
  git -C "$THEME_DIR" update-index --no-skip-worktree "${GENERATED[@]}"
  git -C "$THEME_DIR" checkout -- "${GENERATED[@]}"
  # The palette is back to default, so the next recolour must not be skipped.
  rm -f "$STATE/drift-recolor.last"
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
git -C "$THEME_DIR" update-index --skip-worktree "${GENERATED[@]}"

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
if (( have < STARTER )); then
  step "Downloading starter wallpapers"
  for _ in $(seq $((STARTER - have))); do
    "$BIN_DIR/drift-wallpaper" --no-apply || true
    sleep 1
  done
fi

mkdir -p "$UNIT_DIR"

# 4. Timer that rotates the wallpaper every two hours: opt-in, but an existing
#    one is kept (and refreshed from the clone) on re-install.
if [[ $TIMER == 1 || ( $TIMER == keep && -f $UNIT_DIR/drift-wallpaper.timer ) ]]; then
  step "Enabling drift-wallpaper.timer"
  enable_units drift-wallpaper timer
  TIMER=1
elif [[ -f $UNIT_DIR/drift-wallpaper.timer ]]; then
  disable_units drift-wallpaper timer
fi

# 5. Recolour from the wallpaper whenever it changes (needs Aether).
if (( RECOLOR )) && ! command -v aether >/dev/null; then
  step "Installing Aether for wallpaper-matched colours"
  omarchy pkg aur add aether </dev/null || { echo "Could not install Aether; keeping the graphite palette" >&2; RECOLOR=0; }
fi
if (( RECOLOR )); then
  step "Enabling drift-recolor.path"
  enable_units drift-recolor path
elif [[ -f $UNIT_DIR/drift-recolor.path ]]; then
  disable_units drift-recolor path
fi

# 6. Apply.
if (( APPLY )); then
  step "Switching to Drift"
  # Remember what to go back to on --uninstall.
  prev=$(cat "$STATE/current/theme.name" 2>/dev/null || true)
  [[ -z $prev || $prev == drift ]] || printf '%s\n' "$prev" >"$STATE/drift-previous-theme"
  OMARCHY_THEME_WAIT=1 omarchy theme set drift </dev/null
  if (( GLASSY )); then
    omarchy bar background glassy
  fi
  if (( RECOLOR )); then
    "$BIN_DIR/drift-recolor" --force || true
  fi
fi

step "Done. Run 'drift-wallpaper' any time for a fresh background."
[[ $TIMER == 1 ]] || echo "   Re-run with --timer to rotate it every two hours."
