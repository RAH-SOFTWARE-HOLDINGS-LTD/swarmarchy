# Path A — Install swarmarchy on the Yoga (recommended)

> **Read this first.** swarmarchy is a **layer, not an OS** — it's applied *on top of* an
> existing Arch install. You are **not** building a bootable USB (that's Path B / `06`, and
> the aarch64 installer ISO isn't buildable yet). Path A is two moves: **(1)** get plain
> **Arch Linux ARM** booting on the Yoga, then **(2)** run one command to apply swarmarchy.
>
> ⚠️ **The hard, risky part is Step 1** — booting Linux on a Snapdragon X Elite. That's
> generic device bring-up, *not* a swarmarchy thing; the community already solved it, so you
> follow their guide. Step 2 (swarmarchy itself) is the easy part.

---

## Step 0 — Windows prep (dual-boot, no wipe)

Do all of this from Windows **before** touching partitions:
- **Back up your BitLocker recovery key** (ideally suspend BitLocker too) — repartitioning
  can otherwise lock you out of Windows.
- **Shrink the Windows partition** (Disk Management → *Shrink Volume*) to free space for
  Linux. Leave the **Windows + EFI** partitions intact — this is dual-boot, no wipe.
- **Copy out the Qualcomm firmware** Linux needs: from
  `C:\Windows\System32\DriverStore\FileRepository\*\` grab the `*.mbn` / `*.jsn` /
  `dtbs.elf` files onto a USB stick. (The Step 1 guide lists exactly which.)
- In **UEFI/BIOS**, disable **Secure Boot**.

## Step 1 — Get bare Arch Linux ARM booting ⚠️ (the hard part)

Device-specific bring-up — **follow the proven guide, don't improvise:**
- **Primary — joske's gist** (Arch ARM on this exact laptop):
  https://gist.github.com/joske/52be3f1e5d0239706cd5a4252606644b
- **Reference — kuruczgy's NixOS config** (authoritative kernel/firmware/quirks list):
  https://github.com/kuruczgy/x1e-nixos-config
- **Optional warm-up:** boot Ubuntu's "Concept" arm64 ISO first to confirm the hardware
  works before committing.

### 1.1 — Prep the installer USB (the part joske's gist hand-waves)

joske boots the **Codelinaro Debian-12 installer image**, then at its initrd shell uses it
to install *Arch* instead. Two lines in the gist are left as an exercise:
> *"unpack the initrd and add this tarball … also add some tools like mkfs.ext4 and fdisk
> (I downloaded debian 12 versions and unpacked the necessary libs and binaries)"*

There are **no commands** for that in the gist. Here's the reproducible version. Do it on a
**Debian 12 `arm64` box** (WSL on a Windows-on-ARM machine is perfect — the tools then
version-match the installer's glibc).

**a) Build a self-contained `fdisk` + `mkfs.ext4` bundle** (binaries + their `.so` deps +
the dynamic loader, so they don't depend on the busybox initrd's libc):
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

# sanity: should print no "not found"
/lib/ld-linux-aarch64.so.1 --library-path "$PWD/opt/tools/lib" --list "$PWD/opt/tools/bin/mke2fs" | grep -i 'not found' || echo "mke2fs OK"
/lib/ld-linux-aarch64.so.1 --library-path "$PWD/opt/tools/lib" --list "$PWD/opt/tools/bin/fdisk"  | grep -i 'not found' || echo "fdisk OK"
```

**b) Unpack the initrd, inject the tools, repack** (an initrd is a gzip'd cpio archive; do
it as root so ownership/`/dev` nodes survive). Point `../initrd.gz` at the untouched initrd
from the Codelinaro image:
```bash
mkdir -p ~/initrd-tools/initrd-work && cd ~/initrd-tools/initrd-work
file ../initrd.gz                                   # confirm compression (gzip here)
sudo sh -c 'zcat ../initrd.gz | cpio -idmv'         # unpack the ORIGINAL into initrd-work/
sudo cp -a ~/initrd-tools/opt .                     # inject /opt/tools ONLY (no rootfs!)
sudo sh -c 'find . | cpio -o -H newc | gzip > ../initrd-new.gz'  # repack (~130-140 MB)
```
(zstd/xz/lz4 original → swap `zcat`/`gzip` for `zstd`/`xz --check=crc32`/`lz4`.)

At the initrd shell on the Yoga you then run `/opt/tools/bin/fdisk.sh /dev/nvme0n1` and
`/opt/tools/bin/mkfs.ext4 /dev/nvme0n1pN` — the wrappers handle the loader/lib path.

> ⚠️ **Do NOT extract the Arch rootfs tarball *into* the initrd** (despite the gist's
> wording). The Codelinaro image is a **raw disk image**: Rufus can only DD-clone it
> (partition scheme is greyed out to **MBR**, no ISO-mode option), so its boot partition is
> a fixed **~300 MB**. The stock initrd is already **127 MB**; add the rootfs and it balloons
> to **~900 MB** — the initrd (which *must* live on the boot partition, and loads entirely
> into RAM) can't fit, and the copy dies with `Input/output error` (= disk full). Also, the
> initrd loads wholly into RAM at boot, so a 900 MB one wastes ~900 MB of RAM.
>
> **Fix: keep the initrd small — original + tools only (≈ 130–140 MB, fits the 300 MB boot
> partition) — and carry the rootfs on a *separate* partition** you mount at install time.

**c) Carry the rootfs on a second FAT32 partition (not inside the initrd).** After Rufus
DD-flashes the image (accept DD/MBR — expected), use Windows **Disk Management** to create a
**second FAT32 partition** in the leftover unallocated space (label it `DATA`; **FAT32, not
NTFS** — the minimal initrd has no NTFS driver, and the ~180 MB tarball is < 4 GB). Then, in
WSL, download the tarball and copy it on (swap `F:` for the new partition's real drive
letter from File Explorer):
```bash
cd ~ && wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz

sudo mkdir -p /mnt/data
sudo mount -t drvfs F: /mnt/data            # F: = the DATA partition's letter
cp ~/ArchLinuxARM-aarch64-latest.tar.gz /mnt/data/    # copy the .tar.gz AS-IS, don't unpack
sync && ls -lah /mnt/data/
```
(If the new partition has no drive letter: Disk Management → right-click it → *Change Drive
Letter and Paths* → *Add*.)

Finally, overwrite the boot partition's `initrd.gz` with your rebuilt `initrd-new.gz`
(from step b — original + tools, no rootfs), and boot the Yoga from the USB (F12).

### 1.2 — At the installer shell: partition → extract → chroot → boot

> ⚠️ **This is an outline, not a verified transcript.** joske's gist is self-described as
> *"from memory, may be incomplete,"* and the exact **kernel / firmware / DTB / bootloader**
> steps are device-specific — take those from the gist **and** kuruczgy's config, and verify
> against current state. The *generic* Arch-ARM steps below are safe to follow literally.
>
> ⚠️ **Dual-boot safety:** the Yoga already has a Windows **EFI System Partition (ESP)** and
> Windows partitions. **Reuse** the existing ESP for `/boot` — do **NOT** `mkfs` it, and never
> touch the Windows partitions. Format **only** your new Linux root. One wrong `mkfs`/`fdisk`
> write here can destroy Windows. Use `lsblk`/`fdisk -l` to identify partitions before acting.

**Generic Arch-ARM steps (same for any install):**
```sh
# --- networking (gist uses a 2nd TTY: Fn+Alt+F2, return with Fn+Alt+F1) ---
# create /etc/wpa_supplicant.conf for your SSID, then bring up wifi + DHCP
# (exact wpa_supplicant/dhcp invocation per the installer environment)

# --- partition: ADD a Linux root in your free space; REUSE the Windows ESP ---
/opt/tools/bin/fdisk.sh /dev/nvme0n1          # create ONE new root partition (note its number)
/opt/tools/bin/mkfs.ext4 /dev/nvme0n1pROOT    # format ONLY the new root — NEVER the ESP

# --- mount target + source, extract the rootfs INTO the target ---
mount /dev/nvme0n1pROOT /mnt                   # new Arch root  (target)
mkdir -p /mnt/boot
mount /dev/nvme0n1pESP  /mnt/boot              # EXISTING Windows ESP — mount only, do NOT mkfs
mkdir -p /mnt/data && mount /dev/disk/by-label/DATA /mnt/data
tar -xpf /mnt/data/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt   # source -> target

# --- chroot in ---
for d in dev proc sys run; do mount --rbind /$d /mnt/$d; done
chroot /mnt /bin/bash

# --- inside the chroot: base config ---
date -s "YYYY-MM-DD HH:MM:SS"                   # sane clock, or pacman-key fails
pacman-key --init && pacman-key --populate archlinuxarm
pacman -Syyu
ln -sf /usr/share/zoneinfo/<Region>/<City> /etc/localtime && hwclock --systohc
# uncomment your locale in /etc/locale.gen, then: locale-gen
passwd                                          # root password
useradd -mG wheel <you> && passwd <you>
# write /etc/fstab (use blkid for the root + ESP UUIDs)
```

**Device-specific steps — DO NOT improvise; pull exact commands from the references:**
- **Kernel:** a Snapdragon-capable kernel — the gist/comments point to the **jhovold** branch
  (`wip/x1e80100-*`); kuruczgy's config is the authoritative kernel/quirks source.
- **Firmware:** install the **Qualcomm firmware** you copied out in Step 0.
- **DTB:** `qcom/x1e80100-lenovo-yoga-slim7x.dtb`.
- **Copy kernel + initrd + DTB from the USB installer** into the NVMe `/boot` (gist does this).
- **Graphics:** the **zink** path the gist mentions (until Mesa **turnip** is solid).
- **Bootloader:** first **edit the USB's GRUB to boot the NVMe** to prove it works, then install
  a persistent bootloader (GRUB or Limine) to the **ESP** — **add** an entry *alongside* Windows,
  don't overwrite the Windows one.

Then exit the chroot, `umount -R /mnt`, reboot, and remove the USB.
> Authoritative sources for the device-specific commands: **joske's gist** (the flow) and
> **kuruczgy's x1e-nixos-config** (kernel/firmware/DTB/quirks) — both linked at the top of Step 1.

You're done with Step 1 when you have a **plain Arch aarch64 desktop that boots and has
networking.** What must be in place:
- a recent **mainline/ALARM `linux-aarch64` (6.14+)**,
- the upstream DTB **`qcom/x1e80100-lenovo-yoga-slim7x.dtb`**,
- the **Qualcomm firmware** from Step 0.

To match swarmarchy's intended scheme use **LUKS + Btrfs subvolumes + Limine**, but *any*
working Arch aarch64 base is fine — the layer doesn't care.

> Rough edges (check the guide for current status): early support had flaky touchpad,
> internal mics, and battery reporting.

## Step 2 — Apply swarmarchy (the easy part)

On the booted Arch ARM, logged in as your user with networking up:
```bash
git clone -b rename-swarmarchy \
  https://github.com/RAH-SOFTWARE-HOLDINGS-LTD/swarmarchy.git ~/.local/share/swarmarchy
source ~/.local/share/swarmarchy/install.sh
```
*(Once you merge `rename-swarmarchy` → `master`, drop the `-b` flag — or use `boot.sh`.)*

This runs the six install phases — **packages → config → theme → login → hardware fixes →
reboot** — and ends at a Sway desktop. Two things it now handles for you automatically:
- **AUR packages:** bootstraps **yay** and pulls walker/bluetui/impala/etc. (no custom
  package repo needed). `displaylink`/`evdi` stay opt-in — add them only if you use the adapter.
- **Login screen:** sets up **greetd + tuigreet** to launch Sway at boot.

Reboot → log in → you're in Sway.

## Step 3 — Verify on bare metal & fix quirks

The VM only proved the *software config*. These need **real hardware** (keys/devices), so
run them once you're in Sway on the Yoga and tick them off:

- [ ] Media keys: volume up/down/mute, mic-mute (`XF86Audio*`) → SwayOSD popup shows
- [ ] Brightness keys (`XF86MonBrightness*`) → backlight changes + OSD
- [ ] `Print` → screenshot · `Super+Ctrl+Print` → OCR text-grab
- [ ] Lid close/open → display off/on · `Super+Ctrl+Delete` → laptop-display toggle
- [ ] `Super+/` → monitor scaling · `Super+Ctrl+N` → nightlight (wlsunset)
- [ ] GPU acceleration (Mesa **turnip** — `vulkaninfo`, or any GL/Vulkan app)
- [ ] Wi-Fi · Bluetooth (Bose headphones) · audio in/out
- [ ] DisplayLink adapter · fingerprint · ZMK keyboard · Razer mouse

Expect a few to need tweaks — that's normal on new hardware. The **x86-only hardware-fix
scripts (Intel/Nvidia/Apple/Asus/Framework) auto-skip on Snapdragon** — harmless.

### Fixing something that's broken (the loop)
Your install at `~/.local/share/swarmarchy` is a **git clone**, so iteration is fast — no
reinstall needed:
1. The `swarmarchy-*` scripts are plain shell — edit the offending one (on the machine, or
   on your dev box).
2. `git commit` + `git push`.
3. Pull it back where needed: `git -C ~/.local/share/swarmarchy pull` (or `swarmarchy-update`).

---

## References
joske gist · kuruczgy NixOS config · Ubuntu Concept ISO · daily-driver writeup
(https://varunpriolkar.com/2025/07/daily-driving-an-arm-linux-laptop/) · remaining
ISO-build blockers in `swarmarchy-iso/BUILD-AARCH64.md`.
