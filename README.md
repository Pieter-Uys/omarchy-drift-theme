# Drift — an Omarchy theme

![Drift palette](preview.png)

A clean, neutral graphite theme for [Omarchy](https://omarchy.org) built to sit
quietly over a wallpaper that keeps changing.

- **Glass bar**: a slim, translucent graphite bar (best with
  `omarchy bar background glassy`), with hairline-bordered menus, popups,
  notifications and lock screen.
- **Calm palette**: soft graphite surfaces with a glacier-blue accent and muted
  status colours.
- **Rotating photography**: `drift-wallpaper` pulls a random, high-resolution
  landscape photo from [Wallhaven](https://wallhaven.cc) every two hours.

## Install

Everything (theme, wallpaper fetcher, timer, glassy bar):

```bash
curl -fsSL https://raw.githubusercontent.com/Pieter-Uys/omarchy-drift-theme/main/install.sh | bash
```

Or from a clone:

```bash
git clone https://github.com/Pieter-Uys/omarchy-drift-theme.git
./omarchy-drift-theme/install.sh            # --no-glassy  --no-timer  --no-apply
```

Theme only (no wallpaper rotation):

```bash
omarchy theme install https://github.com/Pieter-Uys/omarchy-drift-theme
```

Re-running `install.sh` updates an existing install. `omarchy theme update`
also pulls the latest version.

## Wallpapers

`drift-wallpaper` asks Wallhaven for:

- SFW only (`purity=100`) in the General category (no anime or people)
- tagged `photography` plus one of: landscape, nature, mountains, lake, sea,
  forest, clouds, snow, desert, coast
- at least 2560×1440, in 16:9, 16:10 or 21:9
- ranked by all-time favourites, random page and pick

Images are saved to `~/.config/omarchy/backgrounds/drift/` (the newest 20 are
kept), so `omarchy theme bg next` cycles through them. The background only
changes while Drift is the active theme.

No wallpapers are shipped in this repo: they belong to their photographers on
Wallhaven.

```bash
drift-wallpaper                                     # fetch and apply a new one now
drift-wallpaper --no-apply                          # fetch only
systemctl --user disable --now drift-wallpaper.timer  # stop rotating
```

## Files

| File | Purpose |
|------|---------|
| `colors.toml` | Palette; Omarchy generates terminal, editor and Hyprland colours from it |
| `shell.toml` | Bar, menus, popups, notifications, lock screen styling |
| `icons.theme` | Icon theme (Yaru-blue) |
| `extras/` | Wallpaper fetcher and its systemd user service and timer |
| `install.sh` | One-shot installer |
