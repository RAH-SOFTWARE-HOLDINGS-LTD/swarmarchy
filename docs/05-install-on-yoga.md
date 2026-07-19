# Path A — Install swarmarchy on the Yoga

> swarmarchy is a **layer, not an OS** — applied on top of an existing Arch install. Not a bootable
> USB (that's Path B / `06`).

Two moves:

1. Get Arch Linux ARM booting (**Step 1** — the hard part)
2. Apply swarmarchy (**Step 2**)

References (don't improvise the device bring-up):

- joske's gist — Arch ARM on this exact laptop
  - https://gist.github.com/joske/52be3f1e5d0239706cd5a4252606644b
- kuruczgy's NixOS config — kernel/firmware/quirks
  - https://github.com/kuruczgy/x1e-nixos-config
- optional warm-up — boot Ubuntu's "Concept" arm64 ISO to confirm the hardware

---

## Step 0 — Windows prep (dual-boot, no wipe)

1. Back up your **BitLocker recovery key**
   - suspend BitLocker if you can — repartitioning can lock you out
2. **Shrink the Windows partition** (Disk Management → *Shrink Volume*)
   - leave Windows + EFI intact — this is dual-boot, no wipe
3. **UEFI/BIOS** → disable **Secure Boot**
4. **Collect Qualcomm FW** — PowerShell as *Administrator* (to include ACL'd dirs):
   ```powershell
   .\copy-qcom-firmware.ps1 -Destination C:\qcom-firmware\
   ```
   - grabs `*.mbn` `*.jsn` `*dtbs.elf` from `…\DriverStore\FileRepository\` + a `MANIFEST.csv`
   - add `*.elf` to also get Wi-Fi/camera blobs
   - reachable from WSL later at `/mnt/c/qcom-firmware`

## Step 1 — Get bare Arch Linux ARM booting ⚠️

### 1.1 — Prep the installer USB in WSL (one self-contained image)

- bakes the rootfs **and** firmware into one enlarged initrd on the image's single FAT boot partition
  - ~935 MB initrd → the boot partition grows ~300 MB → ~1.5 GB (loads to RAM; needs ≥ 4 GB free)

- **a) Build a self-contained `fdisk` + `mkfs.ext4` bundle**
  - binaries + libs + loader, so they don't need the busybox initrd's libc

```bash
mkdir -p ~/initrd-tools && cd ~/initrd-tools
apt-get download e2fsprogs fdisk
for d in *.deb; do dpkg-deb -x "$d" extract; done

mkdir -p opt/tools/bin opt/tools/lib
cp extract/sbin/fdisk extract/sbin/mke2fs opt/tools/bin/
for b in opt/tools/bin/fdisk opt/tools/bin/mke2fs; do
  ldd "$b" | grep -o '/[^ ]*\.so[^ ]*' | while read -r l; do cp -Lv "$l" opt/tools/lib/; done
done
cp -Lv /lib/ld-linux-aarch64.so.1 opt/tools/lib/

# wrappers that pin the bundled loader/libs -> callable as-is at the initrd shell
cat > opt/tools/bin/mkfs.ext4 <<'EOF'
#!/bin/sh
exec /opt/tools/lib/ld-linux-aarch64.so.1 --library-path /opt/tools/lib /opt/tools/bin/mke2fs -t ext4 "$@"
EOF
cat > opt/tools/bin/fdisk.sh <<'EOF'
#!/bin/sh
exec /opt/tools/lib/ld-linux-aarch64.so.1 --library-path /opt/tools/lib /opt/tools/bin/fdisk "$@"
EOF
chmod +x opt/tools/bin/mkfs.ext4 opt/tools/bin/fdisk.sh
```

- **b) Set up WSL + inputs**
  - tools, rootfs tarball, and point `SRC` at the image

```bash
cd ~
sudo apt-get install -y util-linux mtools dosfstools cpio gzip
wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
SRC=/mnt/c/Users/<you>/Downloads/<codelinaro>.img       # the DOWNLOADED image, left untouched
```

- **c) Bake the fat initrd (original initrd + tools + rootfs)**
  - `sudo` preserves the original's `/dev` nodes
  - no `~/initrd.orig.gz`? pull it from SRC: `MTOOLS_SKIP_CHECK=1 mcopy -i "$SRC"@@$((2048*512)) ::/initrd.gz ~/initrd.orig.gz`

```bash
rm -rf ~/initrd-baked && mkdir ~/initrd-baked && cd ~/initrd-baked
sudo sh -c 'zcat ~/initrd.orig.gz | cpio -idmv'
sudo cp -a ~/initrd-tools/opt .                         # -> /opt/tools/
sudo cp ~/ArchLinuxARM-aarch64-latest.tar.gz root/      # -> /root/
sudo sh -c 'find . | cpio -o -H newc | gzip > ~/initrd.baked.gz'    # ~905 MB
```

- **d) Append the firmware as a second cpio segment**
  - the kernel concatenates initramfs archives
  - `cp -r` (not `-a`) so drvfs's 777/ownership don't carry into the initramfs

```bash
rm -rf ~/fwseg && mkdir -p ~/fwseg/root && cp -r /mnt/c/qcom-firmware ~/fwseg/root/   # straight off Windows C:\
( cd ~/fwseg && find root | cpio -o -H newc 2>/dev/null | gzip ) > ~/fw.cpio.gz
cat ~/initrd.baked.gz ~/fw.cpio.gz > ~/initrd.final.gz   # ~935 MB
zcat ~/initrd.final.gz | grep -a -c 'qcom-firmware/MANIFEST.csv'    # expect 1
```

- **e) Extract SRC's boot tree, swap in the fat initrd**
  - `mtools @@offset` reads the FAT (sector 2048) straight out of the file

```bash
O=$((2048*512))
rm -rf ~/p1extract && mkdir ~/p1extract
MTOOLS_SKIP_CHECK=1 mcopy -s -i "$SRC"@@$O "::/*" ~/p1extract/
cp ~/initrd.final.gz ~/p1extract/initrd.gz
```

- **f) Rebuild that partition as a larger FAT, copy the tree back**

```bash
rm -f ~/p1.img; truncate -s 1500M ~/p1.img
mkfs.vfat -F32 -n BOOT ~/p1.img
( cd ~/p1extract && MTOOLS_SKIP_CHECK=1 mcopy -s -i ~/p1.img boot boot.cat dtb EFI gtk initrd.gz linux :: )
```

- **g) Assemble the whole-disk image**
  - one MBR partition, type 83 bootable, at sector 2048

```bash
rm -f ~/usb-single.img
SECT=$(( $(stat -c%s ~/p1.img) / 512 ))
truncate -s $(( (2048 + SECT) * 512 )) ~/usb-single.img
printf 'label: dos\nunit: sectors\nstart=2048, size=%s, type=83, bootable\n' "$SECT" | sfdisk ~/usb-single.img
dd if=~/p1.img of=~/usb-single.img bs=512 seek=2048 conv=notrunc status=progress
```

- **h) Verify + copy out to flash**

```bash
MTOOLS_SKIP_CHECK=1 mdir -i ~/usb-single.img@@$O ::      # linux + initrd.gz present
cp ~/usb-single.img /mnt/c/Users/<you>/Downloads/usb-single.img
```

- Rufus DD-flash `usb-single.img` (accept DD/MBR)

### 1.2 — At the installer shell: partition → extract → chroot

> ⚠️ **Outline, not a verified transcript** — take device-specific kernel/DTB bits from the gist + kuruczgy.

> 🪤 **Dual-boot / ESP — mount at `/boot/efi`, never `/boot`:**

Layout (add-only):

| Partition | Recommendation |
|---|---|
| **ESP** (existing Windows EFI) | reuse, mount at **`/boot/efi`**, never `mkfs` |
| **`/boot`** | directory on the ext4 root, not a partition |
| **root `/`** | **ext4** (simplest) or Btrfs (swarmarchy's scheme; needs `btrfs-progs` in initrd + Limine) |
| **swap** | none — the layer sets up zram |

- LUKS: swarmarchy targets LUKS+Btrfs+Limine
  - skip it for the first boot; add on reinstall

- **a) Identify disks — never guess** (`lsblk` is usually missing here)

```sh
cat /proc/partitions                             # every disk + partition
blkid                                            # UUID / LABEL / TYPE
/opt/tools/bin/fdisk.sh -l /dev/nvme0n1          # best overview; spot the EFI System partition
ip link                                          # wifi iface

NVME=/dev/nvme0n1        # internal drive; the USB is a separate disk
ESP=${NVME}p1            # existing Windows ESP — reuse, never format
```

- **b) Partition → extract → firmware → chroot**
  - **i) Wi-Fi** — you're root here (no `sudo`); the iface name varies (note `P4` vs `P5`)
    ```sh
    ip link                                              # find your wifi iface, e.g. wlP4p1s0
    wpa_passphrase "SSID" "PASSWORD" > /etc/wpa_supplicant.conf
    wpa_supplicant -i wlP4p1s0 -c /etc/wpa_supplicant.conf   # foreground; hangs after CTRL-EVENT-CONNECTED = OK
    ```
    - in a 2nd TTY (Fn+Alt+F2) get a lease + verify:
    ```sh
    dhcpcd -4 wlP4p1s0                                    # or: dhclient wlP4p1s0
    ip addr show wlP4p1s0                                 # want an inet line
    ping -c3 1.1.1.1
    ```
    - stuck? `wpa_cli -i wlP4p1s0 status` → `COMPLETED` = link OK (fail now = DHCP) · `4WAY_HANDSHAKE_FAILED` = wrong PSK · `INACTIVE` = no valid network block
  - **ii) Partition + format the new root**
    ```sh
    /opt/tools/bin/fdisk.sh "$NVME"     # create ONE new root partition in the free space
    cat /proc/partitions                # note the NEW partition number (nvme0n1pN)
    ROOT=${NVME}p6                      # <-- set to the partition you just created
    /opt/tools/bin/mkfs.ext4 "$ROOT"    # format ONLY the new root — NEVER $ESP
    ```
  - **iii) Mount + verify + extract**
    - mount the real disk FIRST; confirm `df -h /mnt` shows the NVMe (not RAM) before extracting
    - busybox `tar` won't auto-decompress `.gz` → pipe through `gunzip`
    ```sh
    mount "$ROOT" /mnt
    df -h /mnt                                               # must show ~250G on the NVMe, not tmpfs
    mkdir -p /mnt/boot/efi && mount "$ESP" /mnt/boot/efi     # ESP at /boot/efi ONLY
    cd /mnt && gunzip -c /root/ArchLinuxARM-aarch64-latest.tar.gz | tar -xpf -
    ```
  - **iv) Copy the firmware onto the root**
    - it's at `/root/qcom-firmware` (baked into the initrd); copy the whole tree
    - the driver loads only what the DTB names; `dmesg` flags any exact-path stragglers post-boot
    ```sh
    mkdir -p /mnt/lib/firmware/qcom
    cp -a /root/qcom-firmware/* /mnt/lib/firmware/qcom/
    ```
  - **v) Bind-mount + chroot**
    - carry DNS in so pacman works inside the chroot
    ```sh
    cp /etc/resolv.conf /mnt/etc/resolv.conf
    for d in dev proc sys run; do mount --rbind /$d /mnt/$d; done
    chroot /mnt /bin/bash
    ```

- **c) Base config (in chroot)**
  - if `/etc/resolv.conf` is a dangling symlink, remake it (Arch default points at a missing stub)
  - the old installer kernel lacks Landlock → pacman needs `--disable-sandbox`

```sh
rm -f /etc/resolv.conf && printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
date -s "YYYY-MM-DD HH:MM:SS"                            # or pacman-key fails
pacman-key --init && pacman-key --populate archlinuxarm
pacman -Syyu --disable-sandbox
ln -sf /usr/share/zoneinfo/<Region>/<City> /etc/localtime && hwclock --systohc
# uncomment your locale in /etc/locale.gen, then:
locale-gen && echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo yoga > /etc/hostname
passwd
useradd -mG wheel <you> && passwd <you>
EDITOR=nano visudo                                      # uncomment %wheel
```

- **d) fstab — from the partition UUIDs**
  - capture the UUIDs into vars, then heredoc; ESP is **vfat**, and `/boot` gets no line (it's on root)

```sh
ROOT_UUID=$(blkid -s UUID -o value /dev/nvme0n1p6)   # your new root
ESP_UUID=$(blkid -s UUID -o value /dev/nvme0n1p1)    # Windows ESP
cat > /etc/fstab <<EOF
UUID=$ROOT_UUID /         ext4 defaults          0 1
UUID=$ESP_UUID  /boot/efi vfat defaults,noatime  0 2
EOF
cat /etc/fstab
```

- **e) Kernel + NetworkManager (in chroot)**

```sh
pacman -S linux-aarch64 linux-firmware mkinitcpio grub efibootmgr networkmanager sudo
ls /boot && ls /boot/dtbs/qcom/ | grep yoga             # kernel Image + Yoga DTB landed on ext4 /boot
ln -s /usr/lib/systemd/system/NetworkManager.service \
      /etc/systemd/system/multi-user.target.wants/       # wifi next boot
```

- done in the chroot → `exit`, then `umount -R /mnt`
- GPU accel = Mesa turnip later; stock `linux-aarch64` boots fine now

### 1.3 — Boot it

The DTB is the catch: `grub-mkconfig` won't emit a `devicetree` line, and the installer can't write EFI
vars. So boot **interactively** from the USB's GRUB first (proves the kernel + DTB), then save that same
recipe once you're in — no `40_custom`, no `grub-mkconfig`.

- **a) First boot — from the USB's GRUB console (nothing to edit)**
  - `reboot`, then F12 → boot the USB again → at the GRUB menu press `c` for a console
  - `ls` and `ls (hd0,gptN)/` to find the partition holding `/boot/Image`, then type (your root's gpt number + device):

```
set root=(hd0,gpt6)                  # your Arch root's gpt number
insmod ext2
linux /boot/Image root=/dev/nvme0n1p6 rw pd_ignore_unused clk_ignore_unused fw_devlink=off efi=novamap cma=128M rootwait loglevel=7
initrd /boot/initramfs-linux.img
devicetree /boot/dtbs/qcom/x1e80100-lenovo-yoga-slim7x.dtb
boot
```

- black screen? GPU firmware, not a broken install — retype the `linux` line with `nomodeset` to reach a console, fix graphics later

- **b) Make it stick — from the now-booted Arch**
  - efivars work here (they didn't in the installer), so install GRUB to the ESP + register the entry:

```sh
sudo grub-install --target=arm64-efi --efi-directory=/boot/efi --removable
sudo efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Arch Linux" -l '\EFI\BOOT\BOOTAA64.EFI'
```

- save the boot recipe as a minimal `/boot/grub/grub.cfg` — the same lines you just typed
  - hand-writing it avoids `40_custom` + `grub-mkconfig`, which both drop the `devicetree` line

```sh
ROOT_UUID=$(blkid -s UUID -o value /dev/nvme0n1p6)
sudo tee /boot/grub/grub.cfg >/dev/null <<EOF
set timeout=3
menuentry "Arch Linux ARM (Yoga Slim 7x)" {
    insmod ext2
    search --no-floppy --set=root --file /boot/Image
    linux /boot/Image root=UUID=$ROOT_UUID rw pd_ignore_unused clk_ignore_unused fw_devlink=off efi=novamap cma=128M rootwait loglevel=7
    initrd /boot/initramfs-linux.img
    devicetree /boot/dtbs/qcom/x1e80100-lenovo-yoga-slim7x.dtb
}
EOF
```

- reboot → GRUB boots Arch on its own; Windows is untouched (F12 → Windows Boot Manager)
- F12 shows no Arch entry? register once from Windows (elevated `cmd`): `bcdedit /copy {bootmgr} /d "Arch"` → `bcdedit /set {GUID} path \EFI\BOOT\BOOTAA64.EFI` → `bcdedit /set {fwbootmgr} displayorder {GUID} /addfirst`

Step 1 done = plain Arch aarch64 that boots with networking:

- `linux-aarch64` 6.14+
- the Yoga DTB
- the Qualcomm firmware

## Step 2 — Apply swarmarchy

```bash
git clone -b rename-swarmarchy \
  https://github.com/RAH-SOFTWARE-HOLDINGS-LTD/swarmarchy.git ~/.local/share/swarmarchy
source ~/.local/share/swarmarchy/install.sh
```

- runs six phases → Sway desktop
- auto-handles AUR (yay + walker/etc.) and greetd+tuigreet login
- reboot → log in → Sway

### Install gotchas

- the installer **aborts on any single error**, and is **idempotent** — fix one thing, re-run:

```sh
cd ~/.local/share/swarmarchy && source install.sh
```

- it **disables mkinitcpio hooks at the start** of each run, re-enabling them only if the run finishes
  - a failed run leaves them off → regenerate before any reboot:

    ```sh
    sudo mkinitcpio -P
    ```

- prerequisites (yay can't build without them):

```sh
sudo pacman -S --needed base-devel fakeroot git go
```

- clear these as they bite (each aborts the run):
  - **`libisl` 404 / `yay: command not found`** — stale DB; refresh, then base-devel installs:

    ```sh
    sudo pacman -Syyu
    ```

  - **`tzupdate` not available for aarch64** — x86-only AUR pkg; find + delete it from the package list:

    ```sh
    grep -rln tzupdate ~/.local/share/swarmarchy/    # then remove the matched line in each file
    ```

  - **`rustup and rust are in conflict`**:

    ```sh
    sudo pacman -Rdd rust && sudo pacman -S rustup && rustup default stable
    ```

  - **AppImage AUR pkgs fail** (`obsidian-appimage`, `localsend`) — skip them (remove from the list), install by hand later
  - **Btrfs/Limine steps fail** (you're on ext4 + GRUB) — harmless; satisfy them, but keep booting via your GRUB:

    ```sh
    sudo pacman -S limine btrfs-progs
    ```

  - **DNS drops mid-run**:

    ```sh
    sudo rm -f /etc/resolv.conf && echo 'nameserver 1.1.1.1' | sudo tee /etc/resolv.conf
    ```

- **mirror stays on Arch Linux ARM** — the Omarchy x86 mirror/repo/multilib repoint is now gated to x86_64, so on aarch64 nothing clobbers your ALARM mirror
- when it finishes, regenerate the initramfs and reboot:

```sh
sudo mkinitcpio -P && sudo reboot
```

## Step 3 — Verify on hardware

- [ ] Media/brightness keys → SwayOSD · `Print` screenshot · lid open/close
- [ ] `Super+/` scaling · `Super+Ctrl+N` nightlight
- [ ] GPU accel (turnip — `vulkaninfo`) · Wi-Fi · Bluetooth · audio
- [ ] DisplayLink · fingerprint · ZMK keyboard · Razer mouse

- x86-only hardware-fix scripts auto-skip on Snapdragon
- fix loop: edit the `swarmarchy-*` script → commit/push → `swarmarchy-update`

### GPU — get off software rendering

- symptom: Sway launches but laggy + characters duplicate; `fastfetch` shows `GPU: Mesa llvmpipe` (CPU rendering)
- fix = the Adreno (`msm`) firmware chain; each missing file is named by:

```sh
dmesg | grep -iE 'adreno|gpu|zap|gmu'
```

- **`gen70500_sqe.fw` / `gen70500_gmu.bin`** ship in `linux-firmware`:

```sh
sudo pacman -Syu linux-firmware && find /lib/firmware -iname 'gen70500*'
```

- **zap shader** — signed, model-specific `qcdxkmsuc8380.mbn` from Windows; the error path is exact:

```sh
sudo mkdir -p /lib/firmware/qcom/x1e80100/LENOVO/83ED/
sudo cp <path>/qcdxkmsuc8380.mbn /lib/firmware/qcom/x1e80100/LENOVO/83ED/
```

- reboot → no more `-2` errors, `gpu hw init` OK, lag gone

### External monitors (USB-C DP-alt) — the ADSP/CDSP firmware fix

- symptom: external USB-C monitors invisible; `DP-1`/`DP-2` stay `disconnected`, `/sys/class/typec/` is **empty**, onboard **audio** is dead too. Confirm the cause:

```sh
dmesg | grep -i remoteproc      # shows -2 (file not found) for adsp/cdsp
```

- cause: the Type-C DP-alt stack (`pmic_glink` / `charger_pd`) needs the **ADSP + CDSP** remoteproc firmware at the exact board path, which the bulk firmware copy doesn't land there
- fix — place the four blobs (from your Step 0 `qcom-firmware/`, or re-extract from Windows), then **reboot** (the audio card only re-probes on a full reboot):

```sh
sudo mkdir -p /lib/firmware/qcom/x1e80100/LENOVO/83ED/
sudo cp qcadsp8380.mbn adsp_dtbs.elf qccdsp8380.mbn cdsp_dtbs.elf \
        /lib/firmware/qcom/x1e80100/LENOVO/83ED/
```

- use the `qcsubsys_ext_{adsp,cdsp}8380.inf*` blobs — *not* the `qcnspmcdm_ext_cdsp8380` NPU variant
- verify after reboot (`typec` non-empty; DP-1/DP-2 connected at 2560x1600@120):

```sh
ls /sys/class/typec/
swaymsg -t get_outputs
```

- no reboot? live re-trigger the DSPs (monitors only; audio still needs a reboot):

```sh
sudo sh -c 'echo start > /sys/class/remoteproc/remoteproc0/state'   # adsp=remoteproc0, cdsp=remoteproc1
```

### Monitor layout (`~/.config/sway/monitors.conf`)

- two externals side by side, laptop below the left one, all scale 1, max res:

```
output DP-1  mode 2560x1600@120Hz scale 1 position 0 0
output DP-2  mode 2560x1600@120Hz scale 1 position 2560 0
output eDP-1 scale 1 position -384 1600     # x = 2560 - 2944 aligns its right edge under DP-1
```

- native DP outputs are safe to `swaymsg reload` live — DisplayLink outputs are **not** (hard-locks)

### Launcher (walker) — GTK4 renders blank on turnip

- walker's window is invisible under GTK4's GL renderer on Adreno/turnip → force the cairo renderer in `~/.config/sway/bindings.conf`:

```
unbindsym $mod+space      # unbind first, or the "overwriting binding" warning pops the red config-error bar
bindsym $mod+space exec env GSK_RENDERER=cairo walker --width 644 --maxheight 300 --minheight 300
```

- walker needs the **elephant** data daemon; start it at login in `~/.config/sway/autostart.conf`:

```
exec systemctl --user start elephant.service
```

- also needs `en_US.UTF-8` generated (done in Step 1.2c `locale-gen`) — GTK4 falls back to C locale otherwise

### DisplayLink dock — skip it

- **not needed** for USB-C hubs that pass DisplayPort through (DP-alt) — those work once the ADSP firmware above is in place (the Anker hub is DP-alt)
- only DisplayLink-**chip** docks (e.g. Plugable USBC-6950PDZ) need the proprietary driver — check for DisplayLink's vendor ID (nothing → you don't need it):

```sh
lsusb | grep -i 17e9
```

- if you ever do use one — install it; its outputs are `DVI-I-*`, and you must **never** `swaymsg reload` a live DisplayLink mode change (hard-locks) — edit config, then reboot/replug:

```sh
yay -S displaylink evdi
```

### Networking that sticks

- **first-time manual connect** (if NetworkManager isn't up yet) — busybox/minimal shells break `<(...)`, so write a real config file:

```sh
ip link                                                       # find iface (name varies — note P4 vs P5)
wpa_passphrase "SSID" "PASSWORD" | sudo tee /etc/wpa_supplicant.conf
sudo wpa_supplicant -i wlP4p1s0 -c /etc/wpa_supplicant.conf   # no -B: watch for CTRL-EVENT-CONNECTED
# in another TTY once connected:
sudo dhcpcd -4 wlP4p1s0
ip addr show wlP4p1s0                                         # want an inet line
ping -c3 1.1.1.1
```

- diagnose — check the state, then read `wpa_state`:

  ```sh
  wpa_cli -i wlP4p1s0 status
  ```

  - `wpa_state=COMPLETED` → link good; any failure after is DHCP
  - `DISCONNECTED` / `4WAY_HANDSHAKE_FAILED` → wrong PSK
  - `INACTIVE` → config has no valid network block
- **make it permanent** — hand off to NetworkManager (don't run both — they fight over the iface):

```sh
sudo systemctl enable --now NetworkManager
nmcli device wifi connect "SSID" password "PASSWORD"
```

- `ping 1.1.1.1` works but names don't? Fix DNS:

```sh
sudo rm -f /etc/resolv.conf && echo 'nameserver 1.1.1.1' | sudo tee /etc/resolv.conf
```

### Login won't stick (flashes back to the greeter)

- not a password problem — read the boot errors:

```sh
journalctl -b -p err
```

- usual causes: a broken login shell or the compositor failing on the GPU (fix above)
  - reset the shell if needed:

    ```sh
    sudo chsh -s /bin/bash <you>
    ```

- test the password on a raw TTY (Ctrl+Alt+F3) to tell a greeter bug from a real auth failure

---

## Troubleshooting

**Flashed USB has no drive letter in Windows** — expected:

- the image tags its partition MBR type `0x83` (Linux), so Windows skips auto-lettering
- assign one (admin PowerShell):

```powershell
Set-Partition -DiskNumber <N> -PartitionNumber 1 -NewDriveLetter E
```

- or `diskpart` → `select disk N` → `select partition 1` → `assign letter=E`
- not visible at all? may be attached to WSL via usbipd
  - `usbipd detach --busid <BUSID>`
- auto-mount every plug-in: flip the type byte
  - `sudo sfdisk --part-type /dev/sdX 1 c` (revert with `83`)

---

## Alternate — two-partition USB (rootfs on a separate DATA partition)

> ⚠️ Tried first, but **the installer's minimal initrd could not mount the second partition** — that's
> why the baked single-image method (1.1) is the main path. Use this only if you have a reason to.

Keeps the initrd small (tools only) and carries the rootfs on a second FAT32 partition you mount at
install time.

> ⚠️ **Don't bake the rootfs into this initrd.**
> - the image's boot partition is a fixed ~300 MB; initrd (127 MB) + rootfs = ~900 MB won't fit (`Input/output error`)
> - keep it small; the rootfs rides on the DATA partition instead

- **a) Build the `fdisk` + `mkfs.ext4` bundle**
  - same as **1.1(a)** (produces `~/initrd-tools/opt`)

- **b) Inject the tools into the initrd, repack**
  - as root, to keep `/dev` nodes
  - point `../initrd.gz` at the Codelinaro initrd

```bash
mkdir -p ~/initrd-tools/initrd-work && cd ~/initrd-tools/initrd-work
sudo sh -c 'zcat ../initrd.gz | cpio -idmv'         # unpack the ORIGINAL (confirm gzip: file ../initrd.gz)
sudo cp -a ~/initrd-tools/opt .                     # inject /opt/tools ONLY (no rootfs!)
sudo sh -c 'find . | cpio -o -H newc | gzip > ../initrd-new.gz'  # repack (~130-140 MB)
```

- zstd/xz/lz4 original → swap `zcat`/`gzip` accordingly

- **c) Create the DATA partition + copy the rootfs**
  - after Rufus DD-flashes (accept DD/MBR), make a second **FAT32** partition in the free space, label `DATA`
  - FAT32 not NTFS — the minimal initrd has no NTFS driver

```bash
cd ~ && wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
sudo mkdir -p /mnt/data
sudo mount -t drvfs F: /mnt/data                    # F: = the DATA partition's letter
cp ~/ArchLinuxARM-aarch64-latest.tar.gz /mnt/data/  # copy AS-IS, don't unpack
```

- no drive letter? Disk Management → *Change Drive Letter and Paths* → *Add* (greyed out → Troubleshooting)

- **d) Copy the Step 0 firmware onto DATA**

```bash
cp -r /mnt/c/qcom-firmware /mnt/data/
```

- overwrite the boot partition's `initrd.gz` with `initrd-new.gz`, then continue at **1.2**
- only difference at the installer shell: mount DATA and pull the rootfs + firmware from it (not `/root/`)
  ```sh
  mkdir -p /mnt/data && mount /dev/disk/by-label/DATA /mnt/data
  cd /mnt && gunzip -c /mnt/data/ArchLinuxARM-aarch64-latest.tar.gz | tar -xpf -
  mkdir -p /mnt/lib/firmware/qcom && cp -a /mnt/data/qcom-firmware/* /mnt/lib/firmware/qcom/
  ```

## References

- joske gist · kuruczgy NixOS config
- [daily-driver writeup](https://varunpriolkar.com/2025/07/daily-driving-an-arm-linux-laptop/)
- ISO blockers in `swarmarchy-iso/BUILD-AARCH64.md`
