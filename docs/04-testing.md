# Testing swarmarchy

You need a running **Sway session** to test the config + scripts. A VM is fine — none
of this needs the real hardware (GPU accel, Wi-Fi, Bluetooth, DisplayLink, fingerprint
are bare-metal only — those are checked on the real machine in `docs/05` Step 3).

**Already have a Linux box or a usable VM? Skip to Step 3.** Otherwise build a throwaway
aarch64 VM in **Steps 1–2**, then run the tests in **Steps 3+**.

> Host here is Windows-on-ARM (Snapdragon). On **Windows 11 Home** use **QEMU** (below).
> On **Pro** you could use Hyper-V instead, but QEMU is the tested path and renders Sway
> more reliably.

---

## Step 1 — Build the VM (QEMU via MSYS2)

Use the **MSYS2 CLANGARM64** shell (the native-ARM one) for everything here.

### 1a. Install QEMU + gather the pieces
```bash
pacman -S mingw-w64-clang-aarch64-qemu
qemu-system-aarch64 --version

mkdir -p ~/vm && cd ~/vm                              # keep EVERYTHING here (avoids path issues)
cp /clangarm64/share/qemu/edk2-aarch64-code.fd .      # adjust via: ls /clangarm64/share/qemu | grep -i aarch64
qemu-img create -f raw efivars.img 64M                # UEFI var store (must be 64M)
qemu-img create -f qcow2 disk.qcow2 60G               # install target disk
# Download the current Ubuntu Server arm64 ISO into ~/vm from
# https://cdimage.ubuntu.com/releases/24.04/release/  (ubuntu-24.04.X-live-server-arm64.iso)
ls -lh ~/vm/ubuntu-*-arm64.iso                        # should be ~2.5–3 GB (a few KB = failed download)
```

### 1b. Boot the installer
The ISO is attached as a **virtio-blk disk** (Ubuntu's hybrid ISO boots that way — a
plain `-cdrom` drops you to the UEFI shell). `bootindex=0` boots it first; `$ISO` picks
up whatever ISO is in `~/vm`:
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
- `whpx` error on launch → delete `-accel whpx` (slow software emulation, but always works).
- Black/broken window → `-display sdl` (note: SDL can freeze on some MSYS2 builds — if so, stay on gtk).

### 1c. Install Ubuntu
Walk the text installer: accept defaults, **use the whole virtual disk** (it's the
throwaway `disk.qcow2`), set a username/password, enable **Install OpenSSH server**.
Finish → **Reboot Now** → close the QEMU window.

---

## Step 2 — Boot it and start Sway

Relaunch **without the ISO** (drop the last two `cd0` lines):
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

Log in, then install the Sway stack and apply the config. **Ubuntu package-name
differences:** `mako` → `mako-notifier`, OCR is `tesseract-ocr`, and `walker` isn't
packaged (so skip the launcher/`swarmarchy-menu` tests later).
```bash
sudo apt update
sudo apt install -y sway swayidle swaylock foot waybar mako-notifier grim slurp \
  wl-clipboard jq tesseract-ocr brightnessctl playerctl pamixer git xdg-terminal-exec

git clone -b rename-swarmarchy \
  https://github.com/RAH-SOFTWARE-HOLDINGS-LTD/swarmarchy.git ~/swarmarchy

export SWARMARCHY_PATH="$HOME/swarmarchy"; export PATH="$SWARMARCHY_PATH/bin:$PATH"
mkdir -p ~/.local/share/swarmarchy ~/.config/swarmarchy/current
ln -sfn "$SWARMARCHY_PATH/default" ~/.local/share/swarmarchy/default
ln -sfn "$SWARMARCHY_PATH/bin"     ~/.local/share/swarmarchy/bin
cp -r "$SWARMARCHY_PATH/config/"* ~/.config/        # ALL configs (matches install/config/config.sh)
swarmarchy-theme-set "Tokyo Night"                  # GENERATES current/theme/{waybar.css,foot.ini,mako.ini,...} from templates

sway                                             # launch from THIS shell so it inherits SWARMARCHY_PATH/PATH
```

**Sending keys into Sway under gtk** (the Windows key won't pass through directly): open
the QEMU monitor with `Ctrl+Alt+2`, type a `sendkey`, then `Ctrl+Alt+1` to return:
- `sendkey meta_l-ret` = Super+Enter → opens a foot terminal
- `sendkey meta_l-1` = Super+1 (workspace 1), `sendkey meta_l-w` = Super+W (close window)

> The git clone needs the branch pushed to GitHub. If it isn't, `scp` the repo in from
> WSL instead.

---

## Step 3 — Static checks (optional; any machine, no Sway needed)
```bash
cd ~/swarmarchy
for f in bin/swarmarchy-*; do bash -n "$f" || echo "SYNTAX FAIL: $f"; done   # all should parse
shellcheck bin/swarmarchy-system-lock bin/swarmarchy-launch-or-focus bin/swarmarchy-capture-screenshot  # optional, style only
```

## Step 4 — Bindings (in the Sway session)
Send these with the monitor (`Ctrl+Alt+2` → `sendkey …` → `Ctrl+Alt+1`):
- [ ] `meta_l-ret` → foot opens
- [ ] `meta_l-1` / `meta_l-2` → switch workspaces (Waybar workspace numbers change)
- [ ] `meta_l-w` → close focused window
- [ ] `meta_l-t` float toggle · `meta_l-f` fullscreen

## Step 5 — Scripts (in a foot terminal)
```bash
swarmarchy-menu-keybindings --print | head   # the cheatsheet renders from your bindings
swarmarchy-cmd-terminal-cwd                   # prints this terminal's directory
swarmarchy-capture-screenshot                 # drag a region with the mouse → ~/Pictures
swarmarchy-system-lock                        # swaylock appears; type your password to unlock
```
- [ ] cheatsheet lists binds with descriptions
- [ ] cwd is correct · screenshot saved + on clipboard · lock + unlock works

## Step 6 — Optional
- `swarmarchy-capture-screenrecording` → prompts to install `wf-recorder`, then records a region
- `swarmarchy-toggle-nightlight` (wlsunset) · `swarmarchy-wm-monitor-scaling-cycle`
- **Skip `walker` / `swarmarchy-menu`** — walker isn't packaged on Ubuntu (works on the real Arch target).

Exit Sway with `swaymsg exit`.

---

If Steps 3–6 pass, the **Sway conversion is sound.** The only remaining risk is hardware
enablement on the real machine — that bare-metal checklist and the fix-it loop now live in
**`docs/05` Step 3**.

---

## Appendix A — Troubleshooting
- **UEFI shell with only `BLK0/BLK1`, no `FS0:`** → no bootable filesystem on the ISO:
  bad/incomplete download (`ls -lh ~/vm/*.iso` ~2.7 GB), or it was attached as a CD — use
  the `virtio-blk-pci` attach in Step 1b.
- **`whpx` error** → drop `-accel whpx`. **Black window** → try `-display sdl` (may freeze;
  if so stay on gtk).
- **foot won't open via a binding** → make sure `xdg-terminal-exec` is installed and you
  launched Sway from a shell with `SWARMARCHY_PATH`/`PATH` exported.
- **"missing waybar.css / foot.ini"** → you skipped `swarmarchy-theme-set` (Step 2); those
  files are generated from `default/themed/*.tpl`, not shipped.

## Appendix B — Partitioning / dual-boot rehearsal
When you want to rehearse the real installer's disk layout (LUKS + Btrfs + Limine,
alongside Windows) without risk: **take a VM snapshot first**, add a second blank VHDX,
and practice on *that* disk (`cryptsetup luksFormat` → `mkfs.btrfs` → subvolumes
`@ @home @snapshots @log @cache` → mount → Limine). The point is to recognize each step
before doing it on the real dual-boot disk. Do the real installer run in this same VM
once the aarch64 ISO builds (Track B).

## Appendix C — Hyper-V (Windows 11 Pro only)
If you have Pro: enable Hyper-V, create a **Generation 2** VM, **disable Secure Boot**
(or set the "Microsoft UEFI CA" template), attach the arm64 ISO, install, and continue
from Step 2. Use the **Basic Session** (not Enhanced) for Sway. QEMU above is the tested
path, though.
