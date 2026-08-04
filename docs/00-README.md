# Swarmarchy — what this is & how it works

Start here. This explains the whole project, how an install actually happens, what
every directory is for, and how you'd rebuild it from scratch.

---

## 1. What this is

Swarmarchy is a fork of **Omarchy** (DHH's opinionated Arch desktop), re-targeted from
x86_64 **Hyprland** to **aarch64 Sway** for a Lenovo **Yoga Slim 7x (Snapdragon X
Elite)**. It is **two repositories**:

| Repo | Role | Bootable? |
|---|---|---|
| **swarmarchy** (this one) | the **post-install configuration layer** — dotfiles + the `swarmarchy-*` command toolbox + package manifests + ordered install scripts. Runs *on top of* a base Arch system. | No |
| **swarmarchy-iso** | the **archiso ISO builder** — produces the bootable installer image that sets up base Arch and then runs swarmarchy. | Produces the ISO |

> Key idea: **swarmarchy is a layer, not an OS.** The ISO (or a manual base Arch
> install) lays down Arch; swarmarchy then turns it into the Sway desktop. That's why
> you can apply swarmarchy on top of *any* working Arch aarch64 base without the ISO.

---

## 2. How an install runs, end to end

1. **ISO boots** into a live environment → a configurator front-ends **archinstall**,
   which performs the base Arch install: dual-boot-safe partition, **LUKS** encryption,
   **Btrfs + subvolumes**, **Limine** bootloader.
2. After the base install, the ISO clones swarmarchy to `~/.local/share/swarmarchy` and
   runs **`install.sh`**.
3. `install.sh` exports `SWARMARCHY_PATH`, puts `bin/` on `PATH`, and **sources the phases
   in order** (each phase is a folder with an `all.sh` that lists its steps):

   | Phase (`install/…`) | What it does |
   |---|---|
   | `helpers/` | shared bash functions (`run_logged`, etc.) |
   | `preflight/` | guards, environment, pacman setup, temporarily disable mkinitcpio |
   | `packaging/` | install packages: **`base.sh`** (reads `swarmarchy-base.packages`), fonts, nvim, **`icons.sh`** (copies `applications/icons`), **`webapps.sh`** (installs the Chromium PWAs), tuis, hardware-specific |
   | `config/` | **`config.sh`** copies `config/*` → `~/.config/`; then theme, git/gpg, timezone, **`detect-keyboard-layout.sh`** (writes your layout into the Sway config), toggles, and a long list of hardware fixes |
   | `login/` | keyring, login manager, hibernation, **Limine + Snapper** boot/snapshot entries |
   | `post-install/` | pacman cleanup, offer reboot |
4. **Reboot → the Sway desktop** (session entry `default/wayland-sessions/swarmarchy.desktop` → `Exec=sway`).

---

## 3. Directory map — what lives where, and why

### swarmarchy (the config layer)
| Directory | What it is | When recreating, put here… |
|---|---|---|
| `install/` | **the brain** — ordered phase scripts (`*/all.sh`) + the `*.packages` manifests | the install steps + the master package lists |
| `bin/` | the **`swarmarchy-*` command toolbox** (~280 scripts): the menu, app launchers, window/monitor toggles, screenshot/OCR, theme, lock/idle, system | every runtime command the desktop & menu call by name |
| `config/` | **user** config templates → copied to `~/.config/` | per-user dotfiles: `sway/`, `waybar/`, `foot/`, `mako/` *(via default)*, `swaylock/`, `walker/`, `btop/`, … |
| `default/` | **shipped** defaults → `~/.local/share/swarmarchy/default/` (the read-only layer the user configs `include`) | `sway/` defaults (bindings/appearance/input/autostart), `bash/`, `limine/`, `snapper/`, `wayland-sessions/` |
| `applications/` | `.desktop` launchers + **`icons/`** (incl. web-app icons like `X.png`) + **`hidden/`** (NoDisplay entries that hide clutter from the launcher) | app launchers + their PNG icons |
| `themes/` | theme folders (colours + wallpapers) — only `tokyo-night` now | one folder per theme |
| `boot.sh` / `install.sh` | entry points (curl-bootstrap / the installer itself) | the top-level run scripts |
| `docs/` | this documentation, numbered in the order it was created | — |

> **Why `applications/icons/X.png` exists:** `install/packaging/webapps.sh` installs a
> set of web-apps as Chromium PWAs (ChatGPT, YouTube, X, WhatsApp, Google\*, GitHub,
> Discord, Zoom, Figma…). Each needs an icon — `X.png` is the icon for the X/Twitter
> web-app. `icons.sh` copies them to `~/.local/share/applications/icons`. To drop a
> web-app, remove its line in `webapps.sh` and its icon.

### swarmarchy-iso (the ISO builder)
| Path | What it is |
|---|---|
| `configs/profiledef.sh` | archiso profile — `arch=aarch64`, `bootmodes=('uefi.grub')` |
| `configs/pacman-online-*.conf` | which package **mirror** the build pulls from (see the `aarch64.example`) |
| `builder/build-iso.sh` | the build: copy the archiso `releng` profile, download every package from the manifests into an **offline mirror**, run `mkarchiso` |
| `builder/archinstall.packages` | the live-env + base-install package set |
| `bin/swarmarchy-iso-make` | the entry command — `./bin/swarmarchy-iso-make` (output → `release/`) |
| `archiso/` | the archiso tool itself (git submodule) |
| `.github/workflows/build-iso.yml` | CI build on an aarch64 runner |
| `BUILD-AARCH64.md` | the remaining aarch64 build blockers + plan |

---

## 4. Recreate from scratch — the "if I started over" walkthrough

To build an ISO that installs Arch on a Snapdragon X Elite and boots into Sway:

1. **Fork the two upstream bases:** `basecamp/omarchy` (config layer) and
   `basecamp/omarchy-iso` (ISO builder) — or fork this project
   (`RAH-SOFTWARE-HOLDINGS-LTD/swarmarchy` + `…-iso`), which already has the
   aarch64/Sway work done.
2. **Define the packages:** edit `install/swarmarchy-base.packages` (desktop + apps) and
   `install/swarmarchy-other.packages` (base system + drivers). Every package is one line
   with an inline `# note`. This is the master list of what the OS installs.
3. **Build `bin/`:** the `swarmarchy-*` scripts — your runtime commands (menu, launchers,
   toggles, capture). The Sway config and menu call these by name, so they must exist.
4. **Build `config/`:** the user dotfiles copied to `~/.config`. The most important is
   `config/sway/` — the compositor config (entry `config`, plus your override files).
5. **Build `default/`:** the shipped defaults the user configs `include` —
   `default/sway/` (bindings/appearance/input/autostart) and the session entry
   `default/wayland-sessions/swarmarchy.desktop` (`Exec=sway`).
6. **Build `applications/`:** `.desktop` launchers + `icons/`; `webapps.sh` defines the
   PWAs and `icons.sh` ships their icons. `hidden/` hides clutter from the launcher.
7. **Wire the install order:** the `install/*/all.sh` files decide which scripts run and
   in what sequence (preflight → packaging → config → login → post-install).
   `install.sh` sources them. Add/remove steps here.
8. **In the iso repo:** set `configs/profiledef.sh` to `arch=aarch64`; point
   `configs/pacman-online-*.conf` at an **Arch Linux ARM** mirror; `build-iso.sh` then
   bakes every package from the manifests into an offline mirror inside the ISO.
9. **Build the ISO:** `./bin/swarmarchy-iso-make` (→ `release/`), or trigger the GitHub
   Action. (See `BUILD-AARCH64.md` for the kernel/firmware/mirror work still required.)
10. **Test:** boot the ISO in a VM (`docs/04-testing.md`), then install on the
    real machine following the references in `BUILD-AARCH64.md`.

---

## 5. The docs, in order
| # | File | What it covers |
|---|---|---|
| 00 | `00-README.md` | this overview |
| 01 | `01-removed-packages.md` | every package cut from upstream Omarchy, and why |
| 02 | `02-summary-of-changes.md` | high-level "what changed" (Sway, ARM64, strip) |
| 03 | `03-hyprland-to-sway-conversion.md` | the compositor conversion + the `bin/` script ports |
| 04 | `04-testing.md` | Testing **in a VM** — build a throwaway VM (or skip if you already have Linux/a VM), then run the config/script tests |
| 05 | `05-install-on-yoga.md` | **Path A** — install on the Yoga (base Arch-ARM + the layer) **and bare-metal verification** (recommended) |
| 06 | `06-custom-iso.md` | **Path B** — build the custom aarch64 USB installer (later/polish) |
| — | `swarmarchy-iso/BUILD-AARCH64.md` | the aarch64 ISO-build blockers + the kernel/firmware plan |
