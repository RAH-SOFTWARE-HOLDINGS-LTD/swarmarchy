# Hyprland → Sway conversion

Status of the compositor conversion for Swarmarchy. **Last updated:** 2026-06-14

## ✅ Config layer (done)

| Hyprland source | Sway result |
|---|---|
| `config/hypr/hyprland.conf` (entry) | `config/sway/config` |
| `default/hypr/looknfeel.conf` | `default/sway/appearance.conf` |
| `default/hypr/input.conf` + `config/hypr/input.conf` | `default/sway/input.conf` + `config/sway/input.conf` |
| `default/hypr/windows.conf` + `apps/*` | `default/sway/windows.conf` (core rules; app rules partial) |
| `default/hypr/autostart.conf` | `default/sway/autostart.conf` |
| `default/hypr/bindings/{tiling-v2,media,clipboard,utilities}.conf` | `default/sway/bindings.conf` |
| `config/hypr/bindings.conf` (apps) | `config/sway/bindings.conf` |
| `config/hypr/monitors.conf` | `config/sway/monitors.conf` |
| `default/hypr/envs.conf` (env block) | `config/environment.d/sway.conf` |
| `config/hypr/hypridle.conf` | `swayidle` invocation in `default/sway/autostart.conf` |
| `config/hypr/hyprlock.conf` | `config/swaylock/config` |
| `default/wayland-sessions/omarchy.desktop` | now `Exec=sway` (was uwsm+Hyprland) |
| Waybar `hyprland/workspaces` | `sway/workspaces` |

## ❌ Dropped — Hyprland-only, no Sway equivalent

- **Decoration/animation:** blur, drop shadows, window rounding, animations, inactive-dim. (Sway has none of these.)
- **Cursor zoom** (`$mod+Ctrl+z`): `cursor:zoom_factor` has no Sway analog.
- **Per-window transparency / gaps / single-square toggles** (`$mod+BackSpace` family): were hyprctl helpers.
- **Window groups** (`togglegroup`, `changegroupactive`): **approximated** with Sway tabbed/stacking layouts (`$mod+g`), but granular group nav is gone.
- **Universal copy/paste/cut** (`sendshortcut`): needs `wtype`; left commented in `default/sway/bindings.conf`.
- **Color picker** (`$mod+Print`): used `hyprpicker`; needs a grim+slurp picker or `wl-color-picker`.
- **`uwsm`**: removed entirely; session env moved to `environment.d`, app launches no longer wrapped in `uwsm-app`.

## ✅ bin-script ports (hyprctl → swaymsg) — DONE

Reference mapping used: `hyprctl monitors -j` → `swaymsg -t get_outputs`; `hyprctl clients/activewindow` → `swaymsg -t get_tree`; `hyprctl devices` → `swaymsg -t get_inputs`; `hyprctl dispatch X` → `swaymsg X`; `hyprctl reload` → `swaymsg reload`; `hyprlock` → `swaylock`; `hypridle` → `swayidle` (via new `omarchy-swayidle`); `hyprsunset` → `wlsunset`. Filenames were **kept** (e.g. `omarchy-hyprland-monitor-*`) to avoid a reference cascade; renaming to `omarchy-sway-*` is an optional later cleanup.

**Ported (~30):** `omarchy-system-lock`, `omarchy-swayidle` (new), `omarchy-toggle-idle`, `omarchy-toggle-nightlight`, `omarchy-cmd-terminal-cwd`, `omarchy-launch-or-focus`, `omarchy-hyprland-window-close-all`, `omarchy-hyprland-monitor-focused`, `omarchy-hyprland-monitor-focused-apple`, `omarchy-hyprland-monitor-scaling-cycle`, `omarchy-hyprland-monitor-internal`, `omarchy-hyprland-toggle{,-enabled,-disabled}`, `omarchy-hyprland-window-pop`, `omarchy-capture-screenshot`, `omarchy-capture-text-extraction`, `omarchy-restart-{hyprctl,hypridle,hyprsunset}`, `omarchy-refresh-hyprlock`, `omarchy-hw-{touchpad,touchscreen}`, `omarchy-toggle-{touchpad,touchscreen}`, `omarchy-brightness-display`, `omarchy-font-set`, `omarchy-update-{git,perform}`, `omarchy-remove-preinstalls`, `omarchy-setup/remove-security-fingerprint` (lock-icon → no-op; PAM auth unchanged), `omarchy-windows-vm`.

**No change needed:** `omarchy-theme-set` (only called the now-ported `omarchy-restart-hyprctl`), `omarchy-refresh-config` (generic file-copier; matched only on a comment).

### ✅ Skip list — resolved
| Item | Resolution |
|---|---|
| `omarchy-menu` | **Curated.** Config-edit + refresh + restart submenus repointed to `~/.config/sway/*` (`sway/config`, `swaylock/config`, `sway/{monitors,input,bindings,looknfeel}.conf`); dropped toggle items (Workspace Layout, Window Gaps, 1-Window Ratio, Screensaver) removed; `*Sway*` cases ordered after `*Swaylock*`/`*Swayosd*` to avoid glob collisions. |
| `omarchy-menu-keybindings` | **Rewritten** to parse `default/sway/bindings.conf` + `config/sway/bindings.conf`, pairing each `bindsym` with its `## Description` comment (no keycode mapping needed — Sway uses named keys). |
| `omarchy-capture-screenrecording` | **Rewritten** around `wf-recorder` (region/output via slurp, optional desktop/mic audio). **Optional install** — offers `omarchy-pkg-add wf-recorder` on first use; not in base packages. Webcam/HDR/portal paths dropped. |
| `omarchy-hyprland-monitor-internal-mirror` | **Rewritten** around `wl-mirror` (mirrors the internal output into a window fullscreened on the external). **Optional install.** wl-mirror's `app_id` match may need tuning per build. |
| `omarchy-hyprland-window-transparency-toggle` | **Dropped** (deleted) — opacity toggle deemed not useful. |
| `omarchy-hyprland-workspace-layout-toggle` | **Dropped** (deleted) — Sway has no dwindle/scrolling layouts. |
| `omarchy-launch-screensaver`, `omarchy-screensaver` | **Dropped** (deleted) — depended on removed `tte`; also removed the `timeout 150` screensaver step from `omarchy-swayidle` (idle now just dims + locks at 5 min). |
| `omarchy-refresh-{hypridle,hyprsunset}` | **Dropped** (deleted) — swayidle has no config file, wlsunset uses CLI args. New `omarchy-refresh-sway` added for the Sway configs. |

> New packages are **optional** (install-on-first-use): `wf-recorder`, `wl-mirror`. Themes purged to `tokyo-night` only (default); the theme *system* is retained.

## ⚠️ Theme system
**Decision:** themes are out of scope for this build. Purged 18 of 19 theme folders, keeping only `tokyo-night` (the installer default — set by `install/config/theme.sh`). Per-theme `sway.conf` border-color files are **not** created (most themes lacked even the Hyprland equivalent). `config/sway/config` still includes `current/theme/sway.conf`, which is simply absent (Sway warns-but-continues).

**Skipped (needs us to tackle together):** fully removing the theme *system* — 31 files read `~/.config/omarchy/current/theme/*` (Waybar CSS, btop, mako, backgrounds), so ripping it out means rewriting those to static colors. Kept `tokyo-night` so the desktop still renders.

## Packages this assumes
Already added in `install/omarchy-base.packages`: `sway swayidle swaylock foot walker xdg-desktop-portal-wlr`. **Still consider:** `wlsunset` (nightlight, replaces hyprsunset), `wtype` (universal copy/paste). `swaylock` base has no blur — use `swaylock-effects` if you want the Hyprland-style blurred lock.
