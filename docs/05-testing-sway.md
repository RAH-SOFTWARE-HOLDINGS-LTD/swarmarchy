# Track A — Sway conversion test checklist

Validate the Sway config + ported `bin/` scripts. **This is architecture-independent** —
`swaymsg`/`grim`/`slurp`/`jq` behave identically on x86_64, so run it on **any**
Arch (or Arch-like) machine/VM with Sway. No aarch64 work required.

> **Prerequisite: a running Sway session.** If you're already on Linux or have a VM
> you can use, just start at §1. If not, build a throwaway aarch64 VM first
> (**`04-vm-setup.md`**), then come back and run the tests here.

Legend: `[ ]` to do · note PASS/FAIL + anything weird next to each line.

---

## 0. Install the test dependencies
```bash
sudo pacman -S --needed sway swayidle swaylock foot waybar mako grim slurp \
  wl-clipboard jq tesseract tesseract-data-eng brightnessctl playerctl \
  pamixer swayosd xdg-desktop-portal-wlr xdg-terminal-exec gum
# AUR (need an AUR helper): walker
```
- [ ] All install cleanly on x86 (proves the package names are valid outside ARM).

## 1. Static checks (no GUI — run from the repo now)
```bash
cd /path/to/swarmarchy
# 1a. Shell syntax of every ported script
for f in bin/omarchy-*; do bash -n "$f" || echo "SYNTAX FAIL: $f"; done
# 1b. (optional) shellcheck for real bugs
shellcheck bin/omarchy-system-lock bin/omarchy-launch-or-focus \
  bin/omarchy-cmd-terminal-cwd bin/omarchy-capture-screenshot \
  bin/omarchy-menu-keybindings bin/omarchy-hyprland-monitor-scaling-cycle
# 1c. jq filters used by scripts are valid (spot-check)
echo '[]' | jq -r 'recurse(.nodes[]?, .floating_nodes[]?)' >/dev/null && echo "jq ok"
```
- [ ] 1a no syntax failures.
- [ ] 1b no obvious errors (warnings are fine).

## 2. Harness (run Sway from the repo, no full install)
Mirror what the real installer does — `install/config/config.sh` copies **all** of
`config/*` to `~/.config/`. Copy (don't selectively symlink) so every supporting
config lands: `xdg-terminals.list` (needed by the terminal binding), `foot/`,
`walker/`, `waybar/`, `swaylock/`, etc.
```bash
export OMARCHY_PATH="$HOME/dev/swarmarchy"            # adjust to your checkout path
export PATH="$OMARCHY_PATH/bin:$PATH"

mkdir -p ~/.local/share/omarchy ~/.config/omarchy/current ~/.config
ln -sfn "$OMARCHY_PATH/default" ~/.local/share/omarchy/default
ln -sfn "$OMARCHY_PATH/bin"     ~/.local/share/omarchy/bin
cp -r "$OMARCHY_PATH/config/"* ~/.config/             # ALL user configs (matches the installer)
# Render the theme. This GENERATES current/theme/{waybar.css,mako.ini,foot.ini,
# swayosd.css,walker.css,...} from default/themed/*.tpl + the theme's colors.toml,
# and sets the wallpaper. (Symlinking the raw theme dir does NOT create these — they
# don't exist until rendered, which is why waybar/foot complain they're missing.)
omarchy-theme-set "Tokyo Night"
```
> **Launch Sway from this same shell** (`sway`) so it inherits `OMARCHY_PATH`/`PATH` —
> otherwise the scripts the keybindings call (`omarchy-cmd-terminal-cwd`, …) aren't found.
> On **Ubuntu** the `Super+Return` terminal binding also needs `xdg-terminal-exec`
> (`sudo apt install xdg-terminal-exec`); on Arch it's already in the package set.
> (If you already symlinked individual dirs, `rm -rf ~/.config/{sway,swaylock,waybar}`
> first, then run the `cp` above.)
- [ ] `sway --validate` → no errors (validates the default `~/.config/sway/config`;
  do **not** pass a path — `sway --validate <path>` errors with "both options and
  positional arguments". A *warning* about the missing `current/theme/sway.conf` is
  expected and harmless).

> Note: `~/.config/environment.d/sway.conf` only auto-applies under a systemd login
> manager. For a manual `sway` launch from a TTY, export the key vars yourself if a
> toolkit app misbehaves: `export XDG_CURRENT_DESKTOP=sway`.

## 3. Sway session smoke test
Start Sway (from a TTY: `sway`, or pick the "Omarchy (Sway)" session in a DM).
- [ ] Sway starts; you get gaps/borders (appearance.conf loaded).
- [ ] Waybar appears at the top; Mako is running (`pgrep -x mako`).
- [ ] `swaybg` shows the wallpaper.

**Bindings** (Super = `$mod`):
- [ ] `Super+Return` → a **foot** terminal opens.
- [ ] `Super+W` closes the focused window.
- [ ] `Super+1`/`Super+2` switch workspaces; `Super+Shift+2` moves window to ws 2.
- [ ] `Super+Left/Right/Up/Down` move focus; `Super+Shift+<arrow>` moves the window.
- [ ] `Super+T` toggles floating; `Super+F` fullscreen; `Super+G` tabbed layout.
- [ ] `Super+Space` opens **walker**; `Super+Alt+Space` opens **omarchy-menu**.

## 4. Script-level tests (run inside a Sway terminal)
```bash
swaymsg -t get_outputs | jq -r '.[].name'      # sanity: IPC works
omarchy-cmd-terminal-cwd                        # prints the terminal's cwd
omarchy-hyprland-monitor-focused                # prints focused output name
omarchy-menu-keybindings --print | head         # cheatsheet renders, "KEY → desc"
```
- [ ] `omarchy-cmd-terminal-cwd` prints your shell's directory (not always `$HOME`).
- [ ] `omarchy-menu-keybindings --print` lists binds with readable descriptions.
- [ ] `Super+K` opens the searchable keybindings menu (needs walker).

**Lock / idle:**
- [ ] `Super+Ctrl+L` (or `omarchy-system-lock`) → swaylock appears; password unlocks;
  display/keyboard backlight come back (`omarchy-system-wake`).
- [ ] Leave idle 5 min (or lower the `timeout` in `omarchy-swayidle` temporarily) →
  it locks. Confirm it does **not** launch a screensaver (that was removed).

**Capture:**
- [ ] `Print` → region select (slurp), screenshot saved to `~/Pictures`, copied to
  clipboard, edit-notification works (satty).
- [ ] `Super+Ctrl+Print` → OCR: select a region with text → text lands on clipboard
  (`wl-paste`).

**Toggles / hardware (where the VM allows):**
- [ ] `Super+Ctrl+N` nightlight → installs/uses `wlsunset`, screen warms; toggle off.
- [ ] Volume/brightness media keys → SwayOSD overlay shows (brightness needs a real
  backlight; may no-op in a VM).
- [ ] `Super+/` monitor scaling cycle → notification shows new scale; value persists
  into `~/.config/sway/monitors.conf`.

## 5. Optional-install paths
- [ ] `omarchy-screenshot` aside, trigger screen recording (`Alt+Print` →
  `omarchy-menu screenrecord`, or run `omarchy-capture-screenrecording`): with
  `wf-recorder` absent you get the **"Install it now?"** gum prompt. Install → it
  records a region to `~/Videos`; run again to stop.
- [ ] Mirror (`omarchy-hyprland-monitor-internal-mirror toggle`): with one display
  it should say "No external monitor". With a second (virtual) output, prompts to
  install `wl-mirror`. *(app_id match may need tuning — see the script's NOTE.)*

## 6. The omarchy-menu, end to end
Open `omarchy-menu` and walk the submenus:
- [ ] **Style → Sway** opens `~/.config/sway/looknfeel.conf` in your editor.
- [ ] **Setup → Config → Sway / Swaylock / Swayosd** open the right files.
- [ ] **Update → Use default config** lists Sway/Swaylock/Swayosd (no Hypr* entries).
- [ ] No menu item references `~/.config/hypr/*` or a deleted script.

---

## ❌ NOT testable in a VM (needs the Snapdragon hardware — Track B)
Don't expect these to work in a VM; they're bare-metal only:
- Adreno GPU acceleration (Mesa **turnip**) — VM gives software/virtio rendering.
- Qualcomm Wi-Fi/Bluetooth (Bose), audio firmware, DisplayLink (`evdi`), fingerprint.
- The Snapdragon-X kernel itself, real backlight/brightness, lid switch, ZMK/Razer USB.

If everything in §1–§6 passes, the Sway conversion is sound and the remaining risk is
entirely Track B (kernel/firmware/drivers).
