<div align="center">

# Drift

**A calm graphite Omarchy theme that recolours itself to match a wallpaper that keeps changing.**

![Omarchy](https://img.shields.io/badge/Omarchy-theme-5e81ac?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Wallpapers](https://img.shields.io/badge/wallpapers-Wallhaven%20SFW-lightgrey?style=flat-square)

[Install](#install) · [Wallpapers](#wallpapers) · [Colours](#colours-from-the-wallpaper) · [Files](#files) · [License](#license)

![Drift with fastfetch and Neovim](screenshot.webp)

</div>

---

A clean, neutral graphite theme for [Omarchy](https://omarchy.org) built to sit quietly over a wallpaper that keeps changing.

## Features

| | |
|---|---|
| **Glass bar** | A slim, translucent graphite bar (best with `omarchy bar background glassy`), with hairline-bordered menus, popups, notifications and lock screen |
| **Colours from the wallpaper** | Every time the background changes, Drift recolours terminals, borders, bar and menus from the image using [Aether](https://github.com/bjarneo/aether)'s palette extraction |
| **Graphite fallback** | Without Aether, a calm graphite palette with a glacier-blue accent |
| **Rotating photography** | `drift-wallpaper` pulls a random, high-resolution landscape photo from [Wallhaven](https://wallhaven.cc) every two hours |

## Install

Everything (theme, wallpaper fetcher, timer, wallpaper-matched colours, glassy bar):

```bash
curl -fsSL https://raw.githubusercontent.com/Pieter-Uys/omarchy-drift-theme/main/install.sh | bash
```

<details>
<summary><b>Other ways to install</b></summary>

<br>

From a clone, with optional flags:

```bash
git clone https://github.com/Pieter-Uys/omarchy-drift-theme.git
./omarchy-drift-theme/install.sh   # --no-glassy --no-timer --no-apply --no-recolor
```

| Flag | Effect |
|---|---|
| `--no-glassy` | Leave the bar background setting as it is |
| `--no-timer` | Install the fetcher but don't rotate wallpapers automatically |
| `--no-apply` | Install everything but don't switch to the theme |
| `--no-recolor` | Keep the fixed graphite palette instead of matching the wallpaper |

Theme only (fixed graphite palette, no wallpaper rotation):

```bash
omarchy theme install https://github.com/Pieter-Uys/omarchy-drift-theme
```

</details>

Re-running `install.sh` updates an existing install. `omarchy theme update` also pulls the latest version.

## Wallpapers

`drift-wallpaper` asks Wallhaven for:

- SFW only (`purity=100`) in the General category (no anime or people)
- tagged `photography` plus one of: landscape, nature, mountains, lake, sea, forest, clouds, snow, desert, coast
- at least 2560×1440, in 16:9, 16:10 or 21:9
- ranked by all-time favourites, random page and pick

Images are saved to `~/.config/omarchy/backgrounds/drift/` (the newest 20 are kept), so `omarchy theme bg next` cycles through them. The background only changes while Drift is the active theme.

> No wallpapers are shipped in this repo: they belong to their photographers on Wallhaven.

| Command | Description |
|---|---|
| `drift-wallpaper` | Fetch and apply a new one now |
| `drift-wallpaper --no-apply` | Fetch only |
| `systemctl --user disable --now drift-wallpaper.timer` | Stop rotating |

## Colours from the wallpaper

`drift-recolor` runs `aether --generate <wallpaper> --no-apply`, writes the extracted palette to the theme's `colors.toml`, renders `shell.toml` from `extras/shell.toml.tpl`, and re-applies Drift without touching the wallpaper. With ImageMagick installed, the accent is the palette colour closest to the wallpaper's dominant hue.

A systemd path unit runs it whenever the background changes, whether from the timer, `omarchy theme bg next` or the background picker. It only acts while Drift is the active theme.

| Command | Description |
|---|---|
| `drift-recolor` | Recolour from the current wallpaper |
| `drift-recolor --force` | Redo it even if this image was already used |
| `drift-recolor --reset` | Back to the graphite palette |
| `systemctl --user disable --now drift-recolor.path` | Stop auto-recolouring |

<details>
<summary><b>How the generated colours stay out of git</b></summary>

<br>

The installer marks `colors.toml` and `shell.toml` with git's skip-worktree flag, so the generated colours stay out of `git status` and don't get in the way of `omarchy theme update`. If the repo's default palette itself ever changes, re-run `install.sh` instead: it restores those two files before pulling and recolours afterwards.

</details>

## Files

| File | Purpose |
|---|---|
| `colors.toml` | Palette; Omarchy generates terminal, editor and Hyprland colours from it |
| `shell.toml` | Bar, menus, popups, notifications, lock screen styling |
| `icons.theme` | Icon theme (Yaru-blue) |
| `extras/drift-wallpaper` | Wallhaven fetcher, with its systemd service and timer |
| `extras/drift-recolor` | Wallpaper-to-palette recolouring, with its path unit and service |
| `extras/shell.toml.tpl` | Shell styling template that `drift-recolor` fills in |
| `install.sh` | One-shot installer |
| `preview.png` | Palette swatch shown in the Omarchy theme picker |
| `screenshot.webp` | The screenshot at the top of this README |

## License

MIT. See [LICENSE](LICENSE). Wallpapers fetched from Wallhaven belong to their photographers and are not covered by this licence.
