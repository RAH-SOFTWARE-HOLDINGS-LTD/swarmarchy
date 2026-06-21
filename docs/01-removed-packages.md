# Swarmarchy — Removed / Changed Packages

**Target machine:** Lenovo Yoga Slim 7x — Snapdragon X Elite **X1E78100** (ARM64 / aarch64), Qualcomm **Adreno X1-85** GPU
**Base:** Swarmarchy 3.8.2 (x86_64) → re-targeted to **aarch64 + Sway** (Hyprland removed)
**Strip level:** Balanced — drop architecture-wrong drivers, Hyprland, and heavy/optional apps; keep dev toolchains and quality-of-life.
**Scope of this file:** the `install/swarmarchy-base.packages` and `install/swarmarchy-other.packages` manifests (these feed both the post-install and the `swarmarchy-iso` builder).
**Last updated:** 2026-06-14

> Legend: **REMOVE** = pulled from the ISO (install later via `pacman`/AUR if wanted) · **REPLACE** = swapped for an ARM/Sway equivalent · **ADD** = new package required by this hardware/compositor.

---

## 1. Architecture-wrong — wrong CPU/GPU/laptop (the bulk of `swarmarchy-other.packages`)

These exist for x86 desktops/laptops that are not this machine. Most will not even build on aarch64.

### NVIDIA (you have an Adreno GPU; ARM has no NVIDIA + no multilib)
| Package | Why removed |
|---|---|
| `nvidia-dkms`, `nvidia-open-dkms`, `nvidia-580xx-dkms` | NVIDIA kernel modules — no NVIDIA GPU |
| `nvidia-utils`, `nvidia-580xx-utils` | NVIDIA userspace — n/a |
| `lib32-nvidia-utils`, `lib32-nvidia-580xx-utils` | 32-bit NVIDIA — no multilib on aarch64 |
| `libva-nvidia-driver` | NVIDIA VAAPI — n/a |
| `egl-wayland` | NVIDIA EGLStream Wayland glue — n/a |

### Wrong GPU Vulkan / video stacks → replaced by Adreno (Mesa)
| Package | Why removed |
|---|---|
| `vulkan-intel` | Intel GPU Vulkan |
| `vulkan-radeon` | AMD GPU Vulkan |
| `vulkan-asahi` | Apple Silicon GPU Vulkan |
| `libvpl`, `vpl-gpu-rt` | Intel oneVPL video encode |
| *(replaced by)* | **ADD `mesa`, `vulkan-freedreno`** — Adreno X1-85 (freedreno/turnip) |

### Intel-only kernel/daemons
| Package | Why removed |
|---|---|
| `linux-ptl`, `linux-ptl-headers` | Intel Panther Lake kernel variant |
| `thermald` | Intel thermal daemon (ARM has its own thermal mgmt) |
| `intel-ipu7-camera`, `intel-lpmd`, `intel-media-driver`, `libva-intel-driver` | Intel camera/power/media *(already removed in working tree)* |

### Other people's laptops
| Package | Why removed |
|---|---|
| `broadcom-wl` | Broadcom x86 Wi-Fi DKMS — your Wi-Fi is Qualcomm |
| `linux-firmware-marvell` | Surface (Marvell) Wi-Fi firmware |
| `asusctl` | ASUS ROG laptop control |
| `tuxedo-drivers-nocompatcheck-dkms` | TUXEDO laptops |
| `dell-xps-touchpad-haptics` | Dell XPS touchpad |
| `yt6801-dkms` | Motorcomm 2.5G Ethernet (Framework) |
| `macbook12-spi-driver-dkms` | MacBook 2015–17 keyboard/trackpad |
| `apple-bcm-firmware`, `apple-t2-audio-config`, `linux-t2`, `linux-t2-headers`, `t2fanrd`, `tiny-dfr` | Apple T2 MacBook support |

### Kernel — replaced
| Package | Action |
|---|---|
| `linux`, `linux-headers` | **REPLACE** with a Snapdragon-X-patched aarch64 kernel (e.g. `linux-x1e` / aarch64-laptops tree). Resolved in the ISO/kernel step. |
| `linux-firmware` | **KEEP** + **ADD** Qualcomm firmware (ath12k Wi-Fi, Adreno A7xx GPU blobs, audio). |

---

## 2. Hyprland → Sway conversion

| Package | Action | Replacement |
|---|---|---|
| `hyprland`, `hypridle`, `hyprlock`, `hyprpicker`, `hyprsunset`, `hyprland-guiutils`, `hyprland-preview-share-picker` | REMOVE *(already removed in working tree)* | `sway`, `swayidle`, `swaylock`, `swaybg`*(kept)*, `swayosd`*(kept)* |
| `xdg-desktop-portal-hyprland` | **REPLACE** | **`xdg-desktop-portal-wlr`** (wlroots screencast/screenshot portal) |
| `uwsm`, `alacritty`, `swarmarchy-walker`, `swarmarchy-nvim` | REMOVE *(already removed)* | terminal → **`foot`** (ADD); launcher → **`walker`** (re-ADD, wlroots-native); nvim → your own config |

> Sway-native pieces **already in the list and kept**: `waybar`, `mako`, `grim`, `slurp`, `satty`, `wl-clipboard`, `swaybg`, `swayosd`, `gtk4-layer-shell`, `polkit-gnome`, `xdg-desktop-portal-gtk`, `qt5-wayland`, `qt6-wayland`.

---

## 3. Heavy / optional apps (balanced strip)

Matches Swarmarchy's own `swarmarchy-remove-preinstalls` list and your keep-list. Re-install any of these any time.

| Package | Why removed |
|---|---|
| `libreoffice-fresh` | Full office suite — large, not requested |
| `obs-studio` | Streaming/recording — large, not requested |
| `kdenlive` | Video editor — large KDE dep chain |
| `gpu-screen-recorder` | NVENC-oriented recorder; OBS gone, Adreno encode unsupported |
| `dotnet-runtime-9.0` | .NET runtime — install per-project |
| `jdk-openjdk` | Java — install per-project |
| `mariadb-libs`, `postgresql-libs` | DB client libs — install per-project |
| `python-poetry-core` | Python build backend — use `mise`/pip later |
| `pinta` | Simple image editor — `satty` covers annotation |
| `xournalpp` | Pen/PDF annotation — Slim 7x has no stylus |
| `evince` | PDF viewer — Chromium has a built-in viewer |
| `cliamp` | CLI music visualizer — cosmetic (on Swarmarchy's removal list) |
| `tobi-try` | Standalone optional preinstall app — unreferenced by any script |
| `python-terminaltexteffects` | Terminal eye-candy — "no fancy UI" |
| `lazydocker` | Docker TUI — not on your keep-list |
| `claude-code` | Wanted, but install post-OS yourself |
| `gnome-calculator` | Walker has a calculator module — redundant |
| `eza` | Not wanted. Only used by guarded `ls`/`lt` aliases in `default/bash/aliases` → falls back to plain `ls`. **Strip those alias lines during config conversion.** |
| `fcitx5`, `fcitx5-gtk`, `fcitx5-qt` | CJK/international input method — not needed (no non-Latin typing) |
| `ruby` | Only used by optional `swarmarchy-install-dev-env`; add via `mise` later |
| `luarocks` | Not needed by base Neovim; only certain plugins pull rocks — `pacman -S` on demand |
| `plymouth` | Boot splash — "no fancy UI" + complicates a custom ARM initramfs |
| `dotnet`/`asdcontrol` | `asdcontrol` = Apple Studio Display brightness — not your hardware |
| `imagemagick` | REMOVE *(already removed in working tree)* — pull on demand |

### x86-only desktop apps → dropped (per "drop them, install later")
| Package | Why removed |
|---|---|
| `signal-desktop` | No aarch64 Linux build — use `signal-cli` or web later |
| `spotify` | No aarch64 Linux build — use a TUI/web client later *(already removed)* |
| `obsidian` | Has an arm64 build, but you chose to install it post-OS *(already removed)* |
| `1password-beta`, `1password-cli` | x86-only / not requested *(already removed)* |
| `typora`, `aether` | Not requested *(already removed)* |
| Microsoft **Edge** | Not in the manifest; x86-only on Linux → use Chromium (aarch64) |

### Tooling not wanted (already removed in working tree)
`yay` (→ re-added as the AUR helper, see §5), `zoxide`, `sddm` (→ login handled by greetd/tty, decided in login step).

---

## 4. Kept — core + your feature list

**Compositor/desktop bits (wlroots-native):** `waybar`, `swaybg`, `swayosd`, `mako`, `grim`, `slurp`, `satty`, `wl-clipboard`, `gtk4-layer-shell`, `polkit-gnome`, `xdg-desktop-portal-gtk`, `qt5-wayland`, `qt6-wayland`, `gum`, `xdg-terminal-exec`.

**Your requested tooling:** `tesseract` + `tesseract-data-eng` (OCR region→text), `tmux`, `nvim`, `lazygit`, `btop`, `fzf` (stock), `ripgrep`, `fd`, `bat`, `dust`, `fastfetch`, `starship`, `tldr`, `tree-sitter-cli`, `ttf-jetbrains-mono-nerd` (Nerd Font).

**Browser/media:** `chromium`, `mpv`, `imv`, `playerctl`, `pamixer`, `wiremix`.

**Audio (Bose headphones):** `pipewire`, `pipewire-alsa`, `pipewire-jack`, `pipewire-pulse`, `wireplumber`, `alsa-utils`, `libpulse`, `gst-plugin-pipewire`.

**Network/Wi-Fi:** `iwd`, `impala`, `wireless-regdb`, `avahi`, `nss-mdns`, `inetutils`, `whois`, `inxi`.

**Bluetooth:** `bluetui` (+ system bluetooth stack via install scripts).

**Printing:** `cups`, `cups-browsed`, `cups-filters`, `cups-pdf`, `system-config-printer`.

**Files/disks:** `nautilus`, `nautilus-python`, `sushi`, `ffmpegthumbnailer`, `gnome-disk-utility`, `gvfs-mtp`, `gvfs-smb`, `gvfs-nfs`, `dosfstools`, `exfatprogs`, `unzip`, `plocate`.

**Dev/security:** `clang`, `llvm`, `rust`, `mise`, `usage`, `github-cli`, `docker`, `docker-buildx`, `docker-compose`, `ufw`, `ufw-docker`, `gnome-keyring`, `libsecret`, `expac`, `jq`, `xmlstarlet`, `socat`, `man-db`, `less`, `bash-completion`, `kernel-modules-hook`.

**Power/boot/snapshots:** `power-profiles-daemon`, `bolt` (USB4), `zram-generator`, `limine`, `limine-mkinitcpio-hook`, `limine-snapper-sync`, `snapper`, `btrfs-progs`, `dkms` (needed to build `evdi` for DisplayLink).

**Theming/fonts:** `gnome-themes-extra` (backs `Adwaita-dark` for GTK3 apps — kept), `kvantum-qt5`, `yaru-icon-theme`, `ttf-ia-writer`, `woff2-font-awesome`, `noto-fonts`, `noto-fonts-emoji`, `noto-fonts-cjk`*, `fontconfig`, `webp-pixbuf-loader`.

**Misc utils:** `brightnessctl`, `libqalculate`, `tzupdate`, `python-gobject`, `libyaml`, `localsend`.

> \* `noto-fonts-cjk` (~300 MB) is kept for *rendering* CJK text in web pages; safe to remove if you never view CJK content (input is already dropped with `fcitx5`).

---

## 5. Added — required by this hardware / compositor

| Package | Reason |
|---|---|
| `sway` | Compositor (replaces Hyprland) |
| `swayidle`, `swaylock` | Idle/lock (replace `hypridle`/`hyprlock`) |
| `foot` | Default terminal (your choice; replaces Alacritty) |
| `walker` | Keyboard-first launcher (re-added; wlroots-native) |
| `xdg-desktop-portal-wlr` | Screencast/screenshot portal for Sway |
| `mesa`, `vulkan-freedreno` | Adreno X1-85 GPU (OpenGL + Vulkan/turnip) |
| `linux-x1e` *(or patched aarch64 kernel)* | Snapdragon X Elite boot/hardware support |
| Qualcomm firmware (ath12k, Adreno, audio) | Wi-Fi, GPU, sound on X1E |
| `displaylink` + `evdi`/`evdi-dkms` | Plugable DisplayLink adapter (`evdi` needs `dkms` — kept) |
| `yay` | AUR helper (replaces `yay-debug`) |

> ZMK custom keyboard and Razer V3 mouse need **no extra packages** — both enumerate as standard USB HID. (Optional: `openrazer`/`razergenie` later for Razer-specific lighting/DPI, but not required for basic function.)

---

## Open items to confirm in later steps
- Exact Snapdragon X kernel package + firmware set (Step 2 / ISO step) — pending current aarch64-laptops state.
- Login manager replacement for `sddm` (likely `greetd` + `tuigreet`, or autologin to Sway) — login step.
- `noto-fonts-cjk` keep/drop (rendering only).
