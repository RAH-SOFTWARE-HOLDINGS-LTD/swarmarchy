# Step 3 — aarch64 VM testing (Hyper-V on Windows-on-ARM)

Goal: validate the parts of swarmarchy that need a **real aarch64 Linux session with
a display**, safely, before touching your dual-boot disk. Two things to get out of it:

- **Path A — GUI Sway smoke test** (do this first; achievable today): run the
  `docs/04-testing-sway.md` §3–§6 checklist against a real Sway session.
- **Path B — installer / partitioning rehearsal**: practice the LUKS + Btrfs +
  Limine dual-boot layout where a mistake costs nothing. Most valuable once the
  aarch64 ISO actually builds (Track B); the manual scheme below lets you rehearse
  the *concepts* now.

> Reality check: a VM uses a generic kernel + virtual GPU, so it **cannot** test
> Adreno acceleration, Qualcomm Wi-Fi/BT/audio, DisplayLink, or fingerprint. Those
> are bare-metal only. The VM proves the *software*, not the *drivers*.

---

## 0. Prerequisites

- **Hyper-V requires Windows 11 Pro/Enterprise.** Check: Settings → System → About →
  "Edition". If it says **Home**, Hyper-V is unavailable — use the **QEMU fallback**
  in the appendix instead (free, and actually renders Sway more reliably).
- Enable Hyper-V (Pro only), in an **admin** PowerShell, then reboot:
  ```powershell
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
  ```
- Download an **ARM64** guest ISO:
  - **Path A (fast):** Ubuntu Server **24.10+ ARM64** (ships sway ~1.9, close to
    Arch; minimal, quick). https://ubuntu.com/download/server/arm
  - **Path B (faithful):** Arch Linux ARM (no turnkey ISO — rootfs/archboot process;
    only needed when you want to test the *actual installer + package manifests*).

---

## 1. Create the Hyper-V VM

1. Open **Hyper-V Manager** (Start → type "Hyper-V Manager").
2. **Action → New → Virtual Machine** → Next.
3. Name it `swarmarchy-test`. Next.
4. **Generation 2** (UEFI — required for aarch64). Next.
5. **Memory**: 6144 MB (6 GB). Leave "Dynamic Memory" on. Next.
6. **Networking**: choose **Default Switch** (gives the VM internet via NAT). Next.
7. **Virtual hard disk**: create new, **60 GB** (sparse, won't use it all). Next.
8. **Installation options**: "Install an operating system from a bootable image
   file" → browse to your ARM64 ISO. Next → Finish.

Then **before first boot**, open the VM's **Settings**:
- **Security → Secure Boot**: either **uncheck** "Enable Secure Boot", or change the
  template to **"Microsoft UEFI Certificate Authority"** (the default "Microsoft
  Windows" template will refuse to boot Linux).
- **Processor**: set to **4** virtual processors.
- **Checkpoints**: leave enabled — you'll snapshot before risky steps.

> Use the **Basic Session** (just connect and watch the console), **not** Enhanced
> Session, for the Sway test — Enhanced uses an RDP path that fights wlroots.

---

## 2. Install the guest OS

**Path A (Ubuntu Server ARM64):** boot the VM, run the installer, accept defaults
(let it use the whole 60 GB virtual disk — it's a throwaway VM, no dual-boot concern
*inside* the VM). Create a user, enable OpenSSH if you like, finish, reboot.

You now have a minimal aarch64 Linux with a TTY login. That's all we need.

---

## 3. Install the test bits (Sway + deps) and apply the config

Log into the VM's TTY and install the compositor stack:
```bash
sudo apt update
sudo apt install -y sway swayidle swaylock foot waybar mako grim slurp \
  wl-clipboard jq tesseract-ocr brightnessctl playerctl pamixer git
```

Get the configs into the VM. Easiest is to clone your repo (push the branch first,
or `scp`/clone from your fork):
```bash
git clone -b convert-to-sway-arm \
  https://github.com/RAH-SOFTWARE-HOLDINGS-LTD/swarmarchy.git ~/swarmarchy
```

Apply the **minimal harness** (same as `04-testing-sway.md` §2 — symlinks the repo into
the omarchy paths so the `include`s and scripts resolve):
```bash
export OMARCHY_PATH="$HOME/swarmarchy"
export PATH="$OMARCHY_PATH/bin:$PATH"
mkdir -p ~/.local/share/omarchy ~/.config/omarchy/current
ln -sfn "$OMARCHY_PATH/default" ~/.local/share/omarchy/default
ln -sfn "$OMARCHY_PATH/config/sway"     ~/.config/sway
ln -sfn "$OMARCHY_PATH/config/swaylock" ~/.config/swaylock
ln -sfn "$OMARCHY_PATH/config/waybar"   ~/.config/waybar
ln -sfn "$OMARCHY_PATH/themes/tokyo-night" ~/.config/omarchy/current/theme
# a wallpaper so swaybg has something
sudo apt install -y ubuntu-wallpapers 2>/dev/null
ln -sfn /usr/share/backgrounds/warty-final-ubuntu.png ~/.config/omarchy/current/background 2>/dev/null || true
```

> **`walker` is AUR-only**, so on Ubuntu the launcher and the full `omarchy-menu`
> won't run — those need an Arch ARM guest (Path B). Everything else (bindings,
> lock, screenshot, OCR, keybindings cheatsheet via `--print`) works here.

---

## 4. Run the tests

Still at the TTY (no display manager needed), start Sway directly:
```bash
PATH="$OMARCHY_PATH/bin:$PATH" sway
```
Sway should come up on the VM's virtual display. Now work through
**`docs/04-testing-sway.md` §3–§6**, in this order:

1. **§3 session/bindings** — `Super+Return` (foot opens), workspaces, focus/move,
   floating/fullscreen/tabbed.
2. **§4 scripts** — open a terminal inside Sway and run:
   ```bash
   swaymsg -t get_outputs | jq -r '.[].name'
   omarchy-cmd-terminal-cwd
   omarchy-menu-keybindings --print | head
   ```
3. **Lock/idle** — `Super+Ctrl+L` (swaylock), unlock; confirm no screensaver fires.
4. **Capture** — `Print` (screenshot to `~/Pictures`), `Super+Ctrl+Print` (OCR).
5. **Toggles** — `Super+/` scaling, `Super+Ctrl+N` nightlight (installs wlsunset).

Note PASS/FAIL per line; send me anything that errors. To exit Sway: `Super+Ctrl+...`
isn't bound to exit (we didn't add one), so use `swaymsg exit` from a terminal, or
switch VTs.

> If Sway fails to start with a DRM/“no backend” error, the Hyper-V virtual GPU
> isn't giving wlroots a KMS device — that's the case to switch to the **QEMU
> fallback** (virtio-gpu gives reliable KMS).

---

## 5. Partitioning / dual-boot rehearsal

**Take a Hyper-V checkpoint first** (right-click VM → Checkpoint) so you can roll back
instantly. Then rehearse the scheme the installer will use on the real machine —
LUKS-encrypted Btrfs with subvolumes + Limine, alongside a pre-existing (simulated
"Windows") partition. On a second blank VM disk (Settings → add a SCSI VHDX), as root:

```bash
# Inspect (your throwaway disk, e.g. /dev/sdb — DOUBLE-CHECK the device!)
lsblk

# 1) Simulate "leave Windows alone": make an EFI + a dummy data partition first,
#    then a Linux partition in the remaining space (this is the "no-wipe" part).
#    Use `cfdisk /dev/sdb` (GPT): p1 = 512M EFI, p2 = 8G "windows", p3 = rest = linux.

# 2) LUKS-encrypt the Linux partition (full-disk encryption, linux only)
cryptsetup luksFormat /dev/sdb3
cryptsetup open /dev/sdb3 cryptroot

# 3) Btrfs + subvolumes (snapshot-friendly layout)
mkfs.btrfs /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
for sv in @ @home @snapshots @log @cache; do btrfs subvolume create /mnt/$sv; done
umount /mnt

# 4) Mount the layout
mount -o subvol=@,compress=zstd,noatime /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,.snapshots,var/log,var/cache,boot}
mount -o subvol=@home /dev/mapper/cryptroot /mnt/home
# ... etc, then mount the EFI partition at /mnt/boot

# 5) From here the real installer pacstraps the base + installs Limine and writes
#    snapshot boot entries. In rehearsal you can stop here — the point is to confirm
#    the partition/LUKS/subvol steps and that the "windows" partition is untouched.
```

What you're proving: the **dual-boot-safe** flow (new partition, not a wipe), that
**LUKS** only wraps the Linux partition, and the **Btrfs subvolume** layout Snapper
will snapshot. When the aarch64 ISO builds (Track B), you boot it in this same VM and
let the real configurator do all of the above — this rehearsal is so you recognize
each step and can sanity-check it.

---

## Appendix — QEMU on Windows-on-ARM via MSYS2 (the tested path)

For **Windows 11 Home** (no Hyper-V). QEMU gives wlroots a clean virtio KMS device.
**Use the "MSYS2 CLANGARM64" shell** (purple icon) — the native-ARM environment — for
all of this. All commands are bash.

### Phase A — Install QEMU + gather the pieces
```bash
pacman -S mingw-w64-clang-aarch64-qemu          # install QEMU (aarch64 host build)
qemu-system-aarch64 --version                    # sanity check

mkdir -p ~/vm && cd ~/vm                          # keep EVERYTHING here (avoids path issues)

# UEFI firmware shipped with QEMU + a writable variable store (must be 64M)
cp /clangarm64/share/qemu/edk2-aarch64-code.fd .  # adjust name via: ls /clangarm64/share/qemu | grep -i aarch64
qemu-img create -f raw efivars.img 64M

qemu-img create -f qcow2 disk.qcow2 60G           # the install target disk

# Download an ARM64 Ubuntu Server ISO into ~/vm. Grab the CURRENT point release from
# https://cdimage.ubuntu.com/releases/24.04/release/  (file: ubuntu-24.04.X-live-server-arm64.iso)
# then drop it in ~/vm. The commands below find it by glob, so the exact version doesn't matter.
ls -lh ~/vm/ubuntu-*-arm64.iso                    # confirm it's ~2.5–3 GB (a few KB = failed download)
```

### Phase B — Boot the installer
The ISO is attached as a **virtio-blk disk** (not a CD) — Ubuntu's hybrid ISO exposes an
EFI partition this way, which EDK2 boots. `bootindex=0` (ISO) boots before `bootindex=1`
(disk). The `ISO=…` line picks up whatever Ubuntu ISO is in `~/vm`:
```bash
cd ~/vm
ISO=$(ls ubuntu-*-arm64.iso | head -1); echo "Booting: $ISO"
qemu-system-aarch64 \
  -M virt -cpu max -accel whpx -m 6144 -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file=edk2-aarch64-code.fd \
  -drive if=pflash,format=raw,file=efivars.img \
  -device virtio-gpu-pci -display gtk \
  -device qemu-xhci -device usb-kbd -device usb-tablet \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -drive if=none,id=hd0,file=disk.qcow2,format=qcow2 \
  -device virtio-blk-pci,drive=hd0,bootindex=1 \
  -drive if=none,id=cd0,format=raw,file="$ISO" \
  -device virtio-blk-pci,drive=cd0,bootindex=0
```

### Phase C — Install Ubuntu (in the QEMU window)
Walk the text installer: accept defaults, **use the entire virtual disk** (it's the
throwaway `disk.qcow2`), set a username/password, enable **Install OpenSSH server** when
offered. Finish → **Reboot Now**, then **close the QEMU window**.

### Phase D — Boot the installed system + run Sway
Relaunch **without the ISO** (delete the last two `cd0` lines so it boots the disk):
```bash
cd ~/vm
qemu-system-aarch64 \
  -M virt -cpu max -accel whpx -m 6144 -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file=edk2-aarch64-code.fd \
  -drive if=pflash,format=raw,file=efivars.img \
  -device virtio-gpu-pci -display gtk \
  -device qemu-xhci -device usb-kbd -device usb-tablet \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -drive if=none,id=hd0,file=disk.qcow2,format=qcow2 \
  -device virtio-blk-pci,drive=hd0,bootindex=1
```
Log in at the console, then install the Sway stack. **Note the Debian/Ubuntu name
differences:** `mako` → **`mako-notifier`**; OCR is `tesseract-ocr`; `walker` is NOT
packaged (AUR-only), so the launcher + full `omarchy-menu` won't run here.
```bash
sudo apt update
sudo apt install -y sway swayidle swaylock foot waybar mako-notifier grim slurp \
  wl-clipboard jq tesseract-ocr brightnessctl playerctl pamixer git

git clone -b convert-to-sway-arm \
  https://github.com/RAH-SOFTWARE-HOLDINGS-LTD/swarmarchy.git ~/swarmarchy

export OMARCHY_PATH="$HOME/swarmarchy"; export PATH="$OMARCHY_PATH/bin:$PATH"
mkdir -p ~/.local/share/omarchy ~/.config/omarchy/current
ln -sfn "$OMARCHY_PATH/default" ~/.local/share/omarchy/default
ln -sfn "$OMARCHY_PATH/bin"     ~/.local/share/omarchy/bin
cp -r "$OMARCHY_PATH/config/"* ~/.config/         # ALL configs (incl. xdg-terminals.list) — matches the installer
ln -sfn "$OMARCHY_PATH/themes/tokyo-night" ~/.config/omarchy/current/theme

# Ubuntu only: the Super+Return binding needs xdg-terminal-exec
sudo apt install -y xdg-terminal-exec 2>/dev/null || true

sway                                              # launch from THIS shell so it inherits OMARCHY_PATH/PATH
```
Then work through §3–§6 above. Exit Sway with `swaymsg exit` from a terminal
(`Super+Return`).

### Troubleshooting
- **Dropped to `UEFI Interactive Shell` with only `BLK0/BLK1` and no `FS0:`** → EDK2
  found no bootable filesystem on the ISO. Almost always a **bad/incomplete download**
  (`ls -lh ~/vm/*.iso` should be ~2.7 GB), or the ISO was attached as a CD — use the
  `virtio-blk-pci` attach above.
- **`whpx` error on launch** → delete `-accel whpx` (runs via slow software emulation,
  but always works).
- **Black or broken window** → swap `-display gtk` → `-display sdl`.
- The `git clone` needs the branch pushed to GitHub; otherwise `scp` the repo in from WSL.

---

## Where this fits
- Path A (GUI Sway) — **do now**, closes `04-testing-sway.md` §3–§6.
- Path B (installer/partitioning) — rehearse the scheme now; do the real installer run
  in this VM once the **aarch64 ISO builds** (Track B blockers in
  `swarmarchy-iso/BUILD-AARCH64.md`).
- Bare metal (drivers) — only after the VM passes and Track B boots.
