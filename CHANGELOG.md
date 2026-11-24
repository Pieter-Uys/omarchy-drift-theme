# Changelog

Drift installs from `main`; tags mark what changed when.

## 1.0.0 — 2026-11-24

First release meant for sharing.

### Added
- `install.sh --uninstall` switches back to the theme you had before Drift
  (Matte Black if it's gone), then removes the units, the `drift-*` links,
  state, the theme and the downloaded wallpapers. Safe to re-run, and tidies
  up after `omarchy theme remove drift`.
- `--timer` turns on the two-hourly wallpaper rotation.
- `backgrounds/1-graphite.jpg`, a gradient made from the palette, so a plain
  `omarchy theme install` has a wallpaper.
- README section "What Drift will and won't do", with each rule linked to
  the test that checks it.
- Characterization tests (`tests/run.sh`), run in GitHub Actions together
  with shellcheck.

### Changed
- **Wallpaper rotation is now opt-in.** A fresh install no longer enables
  the timer. Re-running the installer keeps a timer you already have, and
  `--no-timer` removes it.
- The static `shell.toml` is re-rendered from the template, so the plain
  theme's bar highlight uses the glacier-blue accent instead of the old
  orange, matching the recoloured theme.

### Fixed
- After `omarchy theme remove drift`, the leftover units skip quietly
  instead of failing on every wallpaper change.
