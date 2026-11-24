#!/bin/bash
# Characterization tests for drift-recolor, drift-wallpaper and install.sh.
#
#   tests/run.sh            run every case and compare with tests/golden/
#   tests/run.sh --update   rewrite the golden files from the current scripts
#   tests/run.sh <case>...  run only the named cases
#
# Each case runs in a throwaway $HOME with a curated PATH: commands that touch
# the desktop, the network or systemd (omarchy, omarchy-theme-set, aether,
# systemctl, curl, sleep) are stubs that log their arguments, and git clones
# are redirected to a local copy of this working tree. The golden file holds
# the exit code, output, command log and the files the case cares about.
set -uo pipefail
export LC_ALL=C  # same sort order and messages on every host

ROOT=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
GOLDEN="$ROOT/tests/golden"
UPDATE=0
cases=()
for arg in "$@"; do
  case $arg in
    --update) UPDATE=1 ;;
    *) cases+=("$arg") ;;
  esac
done

WORK=$(mktemp -d)
[[ -n ${KEEP_WORK:-} ]] || trap 'rm -rf "$WORK"' EXIT

# --- shared fixtures -------------------------------------------------------

# Real system commands, minus the ones a case must not reach.
make_sys() {
  local dir=$1 f; shift
  mkdir -p "$dir"
  for f in /usr/bin/*; do ln -s "$f" "$dir/${f##*/}"; done
  ln -sf "$ROOT/tests/vendor/omarchy-theme-color" "$dir/omarchy-theme-color"
  for f in aether "$@"; do rm -f "$dir/$f"; done
}
make_sys "$WORK/sys"

# The goldens are made with the vendored resolver, so they match on any host.
# Say so when the desktop's Omarchy has moved on: refresh the vendor and goldens.
installed=$(command -v omarchy-theme-color || true)
if [[ -n $installed ]] && ! cmp -s <(tail -n +7 "$ROOT/tests/vendor/omarchy-theme-color") <(tail -n +2 "$installed"); then
  echo "note: installed omarchy-theme-color differs from tests/vendor/ (Omarchy updated?)" >&2
fi
make_sys "$WORK/sys-nojq" jq

FIX="$WORK/fixtures"
mkdir -p "$FIX"
magick -size 64x36 xc:'#c03a2b' "$FIX/red.png"
magick -size 64x36 xc:'#2b5cc0' "$FIX/blue.png"
magick -size 64x36 xc:'#808080' "$FIX/grey.png"
magick -size 64x36 xc:'#3c9a4a' "$FIX/green.png"

# A palette in Aether's shape: its accent is always the blue slot.
cat >"$FIX/aether-colors.toml" <<'EOF'
accent = "#5a8fd0"
background = "#141820"
foreground = "#dfe3ea"
selection = "#2c3440"
cursor = "#dfe3ea"
color0 = "#141820"
color1 = "#d0645a"
color2 = "#6fb07a"
color3 = "#d6b46a"
color4 = "#5a8fd0"
color5 = "#b07ac4"
color6 = "#5ab4b8"
color7 = "#c8ccd4"
color8 = "#3a4250"
color9 = "#e07c72"
color10 = "#86c491"
color11 = "#e4c684"
color12 = "#78a6e0"
color13 = "#c492d4"
color14 = "#74c8cc"
color15 = "#eef1f5"
EOF

# A git repo of the working tree, standing in for the GitHub clone.
REPO="$WORK/repo"
mkdir -p "$REPO"
(cd "$ROOT" && git ls-files -co --exclude-standard | grep -v '^tests/' | tar -cf - -T -) | tar -xf - -C "$REPO"
git -C "$REPO" init -q
git -C "$REPO" add -A
git -C "$REPO" -c user.name=test -c user.email=test@example.com commit -qm fixture

# --- stubs -----------------------------------------------------------------

make_stubs() {
  local bin=$1
  mkdir -p "$bin"

  cat >"$bin/log-call" <<'EOF'
#!/bin/bash
# log-call <name> <args>...: one normalised line per call
line="$*"
line=${line//$T/<T>}
line=${line//$WORK/<W>}
line=$(sed -E 's#/tmp/tmp\.[A-Za-z0-9]+#<tmp>#g; s#q=[^& ]*#q=<topic>#g' <<<"$line")
printf '%s\n' "$line" >>"$T/log"
EOF

  cat >"$bin/sleep" <<'EOF'
#!/bin/bash
exit 0
EOF

  cat >"$bin/systemctl" <<'EOF'
#!/bin/bash
log-call systemctl "$@"
EOF

  cat >"$bin/omarchy-theme-set" <<'EOF'
#!/bin/bash
log-call omarchy-theme-set "skip_bg=${OMARCHY_THEME_SKIP_BACKGROUND:-}" "$@"
echo "$1" >"$HOME/.local/state/omarchy/current/theme.name"
EOF

  cat >"$bin/omarchy" <<'EOF'
#!/bin/bash
log-call omarchy "wait=${OMARCHY_THEME_WAIT:-}" "$@"
state="$HOME/.local/state/omarchy/current"
case "$1 $2" in
  "theme set")
    mkdir -p "$state"
    echo "$3" >"$state/theme.name"
    first=$(ls -1 "$HOME/.config/omarchy/backgrounds/$3"/* 2>/dev/null | head -1)
    [[ -z $first ]] || ln -sfn "$first" "$state/background"
    ;;
  "theme bg") ln -sfn "$4" "$state/background" ;;
  "pkg aur")
    [[ -z ${PKG_FAIL:-} ]] || exit 1
    cp "$STUBS/aether.real-stub" "$STUBS/aether"
    ;;
esac
EOF

  cat >"$bin/aether.real-stub" <<'EOF'
#!/bin/bash
log-call aether "$@"
out=""
while (( $# )); do
  [[ $1 == --output ]] && out=$2
  shift
done
case ${AETHER_MODE:-ok} in
  fail) echo "aether: could not read image"; exit 1 ;;
  empty) exit 0 ;;
  ok) cp "$FIX/aether-colors.toml" "$out/colors.toml" ;;
esac
EOF
  cp "$bin/aether.real-stub" "$bin/aether"

  cat >"$bin/curl" <<'EOF'
#!/bin/bash
log-call curl "$@"
[[ -z ${CURL_FAIL:-} ]] || exit 22
out=""
args=("$@")
for (( i = 0; i < ${#args[@]}; i++ )); do
  [[ ${args[i]} == -o ]] && out=${args[i+1]}
done
if [[ -n $out ]]; then
  cp "$FIX/red.png" "$out"
  exit 0
fi
n=$(( $(cat "$T/curl-count" 2>/dev/null || echo 0) + 1 ))
echo "$n" >"$T/curl-count"
paths=${CURL_PATHS:-wallhaven-new$n.jpg}
jq -n --arg paths "$paths" '{
  meta: {last_page: 1},
  data: ([$paths | split(" ")[] | {purity: "sfw", path: ("https://w.wallhaven.cc/full/" + .)}]
         + [{purity: "nsfw", path: "https://w.wallhaven.cc/full/wallhaven-nsfw.jpg"}])
}'
EOF

  chmod +x "$bin"/*
}

# --- sandbox helpers -------------------------------------------------------

# new_case: fresh $HOME with Drift installed from the fixture repo.
new_case() {
  T="$WORK/case-$1"
  rm -rf "$T"
  mkdir -p "$T/home" "$T/run"
  export T WORK HOME="$T/home" XDG_RUNTIME_DIR="$T/run" STUBS="$T/bin" FIX
  make_stubs "$STUBS"
  export PATH="$STUBS:$WORK/sys"
  : >"$T/log"
  STATE="$HOME/.local/state/omarchy"
  THEME="$HOME/.config/omarchy/themes/drift"
  BG="$HOME/.config/omarchy/backgrounds/drift"
  unset AETHER_MODE CURL_FAIL CURL_PATHS PKG_FAIL
  {
    printf '#!/bin/bash\n'
    printf 'args=(); for a; do [[ $a == https://github.com/* ]] && a=file://%s; args+=("$a"); done\n' "$REPO"
    printf 'exec /usr/bin/git "${args[@]}"\n'
  } >"$STUBS/git"
  chmod +x "$STUBS/git"
}

# with_theme: Drift cloned and active, as after install.
with_theme() {
  git clone -q "file://$REPO" "$THEME"
  mkdir -p "$STATE/current" "$BG"
  echo drift >"$STATE/current/theme.name"
}

set_background() { ln -sfn "$1" "$STATE/current/background"; }

# run <label> <command>...: record exit code and normalised output.
run() {
  local label=$1 status; shift
  "$@" >"$T/out" 2>&1
  status=$?
  {
    echo "### $label (exit $status)"
    sed -E "s#$T#<T>#g; s#$WORK#<W>#g; s#/tmp/tmp\.[A-Za-z0-9]+#<tmp>#g; s#drift-backup-[0-9]+#drift-backup-<time>#g; s#^Fetched [a-z]+:#Fetched <topic>:#; s#found for '[a-z]+'#found for '<topic>'#" "$T/out"
  } >>"$T/result"
}

# show <title> <command>...: append a normalised section to the result.
show() {
  local title=$1; shift
  {
    echo "### $title"
    "$@" 2>&1 | sed -E "s#$T#<T>#g; s#$WORK#<W>#g; s#drift-backup-[0-9]+#drift-backup-<time>#g"
  } >>"$T/result"
}

show_log() { show "command log" cat "$T/log"; }
theme_files() {
  show "colors.toml" cat "$THEME/colors.toml"
  show "shell.toml vs default" diff "$REPO/shell.toml" "$THEME/shell.toml"
  show "last" cat "$STATE/drift-recolor.last"
}

RECOLOR="$ROOT/extras/drift-recolor"
WALLPAPER="$ROOT/extras/drift-wallpaper"
INSTALL="$ROOT/install.sh"

# --- drift-recolor cases ---------------------------------------------------

case_recolor_not_drift() {
  with_theme
  echo tokyo-night >"$STATE/current/theme.name"
  set_background "$FIX/red.png"
  run "recolor" "$RECOLOR"
  show_log; theme_files
}

case_recolor_switching() {
  with_theme
  touch "$STATE/current/next-theme"
  set_background "$FIX/red.png"
  run "recolor" "$RECOLOR"
  show_log; theme_files
}

case_recolor_red() {
  with_theme
  set_background "$FIX/red.png"
  run "recolor" "$RECOLOR"
  show_log; theme_files
}

case_recolor_green() {
  with_theme
  set_background "$FIX/green.png"
  run "recolor" "$RECOLOR"
  show_log; theme_files
}

case_recolor_grey_keeps_aether_accent() {
  with_theme
  set_background "$FIX/grey.png"
  run "recolor" "$RECOLOR"
  show_log; theme_files
}

case_recolor_skips_same_wallpaper() {
  with_theme
  set_background "$FIX/red.png"
  run "first" "$RECOLOR"
  run "second" "$RECOLOR"
  run "forced" "$RECOLOR" --force
  show_log; theme_files
}

case_recolor_explicit_image() {
  with_theme
  set_background "$FIX/red.png"
  run "recolor blue" "$RECOLOR" "$FIX/blue.png"
  run "then automatic" "$RECOLOR"
  show_log; theme_files
}

case_recolor_reset() {
  with_theme
  set_background "$FIX/red.png"
  run "recolor" "$RECOLOR"
  run "reset" "$RECOLOR" --reset
  run "then automatic" "$RECOLOR"
  show_log; theme_files
}

case_recolor_not_an_image() {
  with_theme
  echo text >"$BG/notes.txt"
  set_background "$BG/notes.txt"
  run "recolor" "$RECOLOR"
  show_log; theme_files
}

case_recolor_no_background() {
  with_theme
  run "recolor" "$RECOLOR"
  show_log
}

case_recolor_aether_fails() {
  with_theme
  set_background "$FIX/red.png"
  export AETHER_MODE=fail
  run "recolor" "$RECOLOR"
  show_log; theme_files
}

case_recolor_aether_empty() {
  with_theme
  set_background "$FIX/red.png"
  export AETHER_MODE=empty
  run "recolor" "$RECOLOR"
  show_log; theme_files
}

case_recolor_no_aether() {
  with_theme
  rm "$STUBS/aether"
  set_background "$FIX/red.png"
  run "recolor" "$RECOLOR"
  run "reset still works" "$RECOLOR" --reset
  show_log
}

# The committed shell.toml is the static fallback a plain `omarchy theme
# install` uses: it must be the template rendered with the default palette.
case_static_shell_matches_template() {
  local key shell
  declare -A c
  while IFS=$'\t' read -r key value; do c[$key]=$value; done \
    < <(omarchy-theme-color --file "$REPO/colors.toml" --all)
  shell=$(<"$REPO/extras/shell.toml.tpl")
  for key in "${!c[@]}"; do shell=${shell//"{{$key}}"/${c[$key]}}; done
  show "differences below the header" diff <(tail -n +3 <<<"$shell") <(tail -n +3 "$REPO/shell.toml")
}

# --- drift-wallpaper cases -------------------------------------------------

case_wallpaper_apply() {
  with_theme
  run "fetch" "$WALLPAPER"
  show_log
  show "backgrounds" ls -1 "$BG"
  show "on screen" readlink "$STATE/current/background"
}

case_wallpaper_no_apply() {
  with_theme
  run "fetch" "$WALLPAPER" --no-apply
  show_log
  show "backgrounds" ls -1 "$BG"
}

case_wallpaper_other_theme() {
  with_theme
  echo tokyo-night >"$STATE/current/theme.name"
  run "fetch" "$WALLPAPER"
  show_log
}

case_wallpaper_prunes_old() {
  with_theme
  local i
  for i in $(seq -w 1 22); do
    cp "$FIX/red.png" "$BG/wallhaven-old$i.jpg"
    touch -d "2026-01-01 00:00:$i" "$BG/wallhaven-old$i.jpg"
  done
  set_background "$BG/wallhaven-old01.jpg"
  run "fetch" "$WALLPAPER" --no-apply
  show "backgrounds" ls -1 "$BG"
}

case_wallpaper_nothing_new() {
  with_theme
  cp "$FIX/red.png" "$BG/wallhaven-have.jpg"
  export CURL_PATHS=wallhaven-have.jpg
  run "fetch" "$WALLPAPER"
  show_log
}

case_wallpaper_unreachable() {
  with_theme
  export CURL_FAIL=1
  run "fetch" "$WALLPAPER"
  show_log
}

# --- install.sh cases ------------------------------------------------------

installed_state() {
  show "bin" bash -c 'for f in "$1"/*; do echo "${f##*/} -> $(readlink "$f")"; done' _ "$HOME/.local/bin"
  show "units" ls -1 "$HOME/.config/systemd/user"
  show "backgrounds" bash -c 'ls -1 "$1" | wc -l' _ "$BG"
  show "skip-worktree" bash -c 'git -C "$1" ls-files -v | grep "^S"' _ "$THEME"
  show "theme" cat "$STATE/current/theme.name"
}

case_install_fresh() {
  run "install" bash "$INSTALL"
  show_log; installed_state; theme_files
}

# The README installs with `curl ... | bash`: the script arrives on stdin.
case_install_piped() {
  run "install" bash -c 'bash <"$1"' _ "$INSTALL"
  show_log; installed_state
}

case_install_update() {
  run "install" bash "$INSTALL"
  echo '# edited' >>"$THEME/colors.toml"
  : >"$T/log"
  run "reinstall" bash "$INSTALL"
  show_log; installed_state; theme_files
}

case_install_backs_up_non_git_theme() {
  mkdir -p "$THEME"
  echo mine >"$THEME/colors.toml"
  run "install" bash "$INSTALL" --no-apply
  show "backup" bash -c 'cat "$1"/.local/share/omarchy-drift-backup-*/colors.toml' _ "$HOME"
  show_log
}

case_install_opt_outs() {
  run "install" bash "$INSTALL"
  : >"$T/log"
  run "reinstall with opt-outs" bash "$INSTALL" --no-glassy --no-timer --no-apply --no-recolor
  show_log; installed_state
}

case_install_installs_aether() {
  rm "$STUBS/aether"
  run "install" bash "$INSTALL" --no-apply
  show_log; installed_state
}

case_install_aether_unavailable() {
  rm "$STUBS/aether"
  export PKG_FAIL=1
  run "install" bash "$INSTALL" --no-apply
  show_log; installed_state
}

case_install_unknown_option() {
  run "install" bash "$INSTALL" --bogus
  show_log
}

case_install_missing_command() {
  export PATH="$STUBS:$WORK/sys-nojq"
  run "install" bash "$INSTALL"
  show_log
}

# --- runner ----------------------------------------------------------------

if (( ${#cases[@]} == 0 )); then
  mapfile -t cases < <(declare -F | awk '{ print $3 }' | sed -n 's/^case_//p')
fi

mkdir -p "$GOLDEN"
failed=0
for name in "${cases[@]}"; do
  new_case "$name"
  : >"$T/result"
  ( "case_$name" )
  if (( UPDATE )); then
    cp "$T/result" "$GOLDEN/$name"
    echo "updated $name"
  elif diff -u "$GOLDEN/$name" "$T/result" >"$T/diff" 2>&1; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    cat "$T/diff"
    failed=1
  fi
done
exit $failed
