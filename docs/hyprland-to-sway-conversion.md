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

### ⏭️ Skipped — need a decision/rewrite (see summary below)
| Script | Why skipped |
|---|---|
| `omarchy-hyprland-monitor-internal-mirror` | Sway has **no native display mirroring** — needs `wl-mirror` (extra pkg) + rewrite |
| `omarchy-hyprland-workspace-layout-toggle` | Sway has no dwindle/scrolling per-workspace layouts |
| `omarchy-hyprland-window-transparency-toggle` | Sway has no per-window opacity *toggle* mechanism |
| `omarchy-capture-screenrecording` | Depends on `gpu-screen-recorder` (removed for ARM/Adreno) — needs `wf-recorder` + rewrite |
| `omarchy-launch-screensaver`, `omarchy-screensaver` | Depend on `tte`/`python-terminaltexteffects` (removed) — they exit *before* any `hyprctl`, so safe as-is |
| `omarchy-menu` | Config-edit submenu points at `~/.config/hypr/*`; several feature toggles are dropped — needs curation (design decision) |
| `omarchy-menu-keybindings` | Relies on `hyprctl -j binds` (no Sway equivalent) — needs a parser for `bindsym` + `##` comments in the sway config |
| `omarchy-refresh-{hypridle,hyprsunset}` | Obsolete — swayidle has no config file, wlsunset uses CLI args (harmless if left) |

## ⚠️ Theme system
**Decision:** themes are out of scope for this build. Purged 18 of 19 theme folders, keeping only `tokyo-night` (the installer default — set by `install/config/theme.sh`). Per-theme `sway.conf` border-color files are **not** created (most themes lacked even the Hyprland equivalent). `config/sway/config` still includes `current/theme/sway.conf`, which is simply absent (Sway warns-but-continues).

**Skipped (needs us to tackle together):** fully removing the theme *system* — 31 files read `~/.config/omarchy/current/theme/*` (Waybar CSS, btop, mako, backgrounds), so ripping it out means rewriting those to static colors. Kept `tokyo-night` so the desktop still renders.

## Packages this assumes
Already added in `install/omarchy-base.packages`: `sway swayidle swaylock foot walker xdg-desktop-portal-wlr`. **Still consider:** `wlsunset` (nightlight, replaces hyprsunset), `wtype` (universal copy/paste). `swaylock` base has no blur — use `swaylock-effects` if you want the Hyprland-style blurred lock.
