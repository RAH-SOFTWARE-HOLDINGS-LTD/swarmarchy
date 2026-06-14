# Swarmarchy — Summary of Changes

**What this is:** an Omarchy fork re-targeted from a themed x86_64 Hyprland desktop to a **lean, keyboard-first Sway desktop on ARM64** for a Lenovo Yoga Slim 7x (Snapdragon X Elite **X1E78100**, Adreno **X1-85** GPU).
**Companion docs:** package-level detail in [`removed-packages.md`](./removed-packages.md). ISO build in the `swarmarchy-iso` repo.
**Last updated:** 2026-06-14

---

## 1. The three big shifts

| Shift | From (Omarchy) | To (Swarmarchy) |
|---|---|---|
| **Compositor** | Hyprland + hypr* (idle/lock/picker/sunset) | **Sway** + `swayidle`/`swaylock`/`swaybg`/`swayosd`, portal `xdg-desktop-portal-wlr` |
| **Architecture** | x86_64 (Intel/AMD/NVIDIA + every supported laptop) | **aarch64** (Snapdragon X kernel + Qualcomm firmware, Adreno via Mesa freedreno/turnip) |
| **Footprint** | Full themed distro w/ office, video, AI, many apps | **Balanced strip** — keep dev + your tooling, drop heavy/optional apps |

Terminal `alacritty` → **`foot`**. Launcher `omarchy-walker` → **`walker`** (kept; wlroots-native). Editor `omarchy-nvim` (opinionated config) → **stock `nvim` + your own config**.

---

## 2. Package changes at a glance

Detail and per-package reasons live in `removed-packages.md`. Summary:

- **Removed — architecture-wrong (~30):** all NVIDIA (7), wrong-GPU Vulkan (intel/radeon/asahi), Intel video/camera/power, Intel `linux-ptl` kernel, and every other-laptop driver (Broadcom, ASUS, Tuxedo, Dell, Framework, Apple-T2, Surface).
- **Removed — Hyprland stack** → replaced with Sway equivalents + `xdg-desktop-portal-wlr`.
- **Removed — heavy/optional apps:** LibreOffice, OBS, Kdenlive, .NET, JDK, DB client libs, plus your explicit cuts (eza, evince, lazydocker, luarocks, ruby, fcitx5, plymouth, gnome-calculator, pinta, xournalpp, claude-code).
- **Removed — x86-only desktop apps** (drop, install later): Signal, Spotify, Obsidian, Edge (use Chromium), 1Password, Typora.
- **Added — for this hardware/compositor:** `sway`, `swayidle`, `swaylock`, `foot`, `walker`, `xdg-desktop-portal-wlr`, `mesa`, `vulkan-freedreno`, Snapdragon-X kernel + Qualcomm firmware, `displaylink` + `evdi`, `yay`.

---

## 3. Peripheral coverage (your hardware)

| Device | How it's handled | Extra packages? |
|---|---|---|
| Bose headphones (BT audio) | PipeWire + WirePlumber + `bluetui` pairing | none |
| Custom ZMK keyboard | Standard USB HID — works out of the box | none |
| Razer V3 mouse | Standard USB HID — works out of the box | optional `openrazer` later for lighting/DPI |
| Wi-Fi (Qualcomm) | `iwd` + `impala`, ath12k firmware | firmware (in `linux-firmware`/qcom) |
| GPU (Adreno X1-85) | Mesa **freedreno** (GL) + **turnip** (Vulkan) | `mesa`, `vulkan-freedreno` |
| Plugable DisplayLink | `displaylink` + `evdi` kernel module (DKMS) | `displaylink`, `evdi`, `dkms` |
| HiDPI / external monitors | Sway `output` scaling (replaces Hyprland monitor menu) | none |

---

## 4. ISO / build implications (important — read before #3)

The `swarmarchy-iso` builder is **archiso-based and hardcoded to x86_64**. Re-targeting to aarch64 is the hardest part of this project and is **not yet done**. What the build currently assumes vs. what ARM needs:

| Build assumption (x86_64) | aarch64 requirement |
|---|---|
| `packages.x86_64`, `releng` profile | `packages.aarch64`; archiso releng is x86-only → need ALARM/`archboot`-style aarch64 assembly |
| Omarchy x86_64 package CDN (`pacman-online-*.conf` + `omarchy-keyring`) | **No aarch64 Omarchy repo exists** — needs an Arch Linux ARM mirror + omarchy-repo packages rebuilt for ARM (`walker`, etc.) |
| `linux-t2` baked into live ISO (build-iso.sh:76) | Replace with Snapdragon-X / generic aarch64 kernel |
| Node.js `linux-x64.tar.gz` (build-iso.sh:59) | `linux-arm64.tar.gz` |
| `intel-ucode`, `amd-ucode`, `sof-firmware` (archinstall.packages) | Drop (x86 microcode); ARM uses in-kernel/qcom firmware |

**Consequence:** the GitHub Action in #3 is delivered as a **correctly-structured aarch64 workflow with the blockers documented inline**, not a green build. It will produce a working ISO only after the build script + mirror work above is completed. Building x86_64 instead would yield an image that cannot boot your Snapdragon machine — so that path is intentionally not taken.

---

## 5. Installer features retained from Omarchy

LUKS full-disk encryption (Linux partition only — **dual-boot safe, no wipe**), Btrfs + subvolumes + Snapper snapshots, Limine boot + snapshot entries, guided user/locale/timezone/hostname, Wi-Fi/ethernet during install, AUR support (`yay`), fingerprint + FIDO2 sudo, UFW firewall + Docker lockdown, suspend/hibernate toggles, Nerd Font. These live in `install/` and the iso `configs/` and are largely architecture-neutral (verified per-script in the config step).

---

## 6. Status & next steps

- [x] **#1** Package removal/keep/add decisions documented (`removed-packages.md`)
- [x] **#2** This summary
- [x] **#3** ISO build GitHub Action (aarch64, with blockers flagged) — in `swarmarchy-iso`
- [ ] **Enact #1** — apply removals/adds to `install/omarchy-base.packages` + `omarchy-other.packages`
- [ ] **Config conversion** — translate `config/hypr/*` + `default/hypr/*` to Sway config (`~/.config/sway/`), Waybar, Mako, Walker, swayidle/swaylock. *(Large; separate step.)*
- [ ] **Build-script aarch64 surgery** — ALARM mirror, `packages.aarch64`, kernel/firmware, Node arm64. *(Separate step; unblocks #3.)*
- [ ] **Kernel/firmware pin** — confirm current Snapdragon-X support (linux-x1e / aarch64-laptops) and exact firmware set.
