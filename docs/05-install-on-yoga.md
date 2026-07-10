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
- **Qualcomm firmware** — Linux also needs Qualcomm's firmware blobs, which live only inside
  Windows. That's its **own step ([1.2](#12--qualcomm-firmware-windows--usb-data-partition))**,
  not done here: it rides on the USB's `DATA` partition, which you create in 1.1. Just know
  it's coming.
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
DD-flashes the image (accept DD/MBR — expected), use Windows **Disk
Management** to create a **second FAT32 partition** in the leftover unallocated space (label it
`DATA`; **FAT32, not NTFS** — the minimal initrd has no NTFS driver, and the ~180 MB tarball is
< 4 GB). Then, in WSL, download the tarball and copy it on (swap `F:` for the new partition's
real drive letter from File Explorer):
```bash
cd ~ && wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz

sudo mkdir -p /mnt/data
sudo mount -t drvfs F: /mnt/data            # F: = the DATA partition's letter
cp ~/ArchLinuxARM-aarch64-latest.tar.gz /mnt/data/    # copy the .tar.gz AS-IS, don't unpack
sync && ls -lah /mnt/data/
```
(You'll add the Qualcomm firmware to this same `DATA` partition next, in **1.2**.)

(If the new partition has no drive letter: Disk Management → right-click it → *Change Drive
Letter and Paths* → *Add*. If that's greyed out, see **Troubleshooting** below.)

Finally, overwrite the boot partition's `initrd.gz` with your rebuilt `initrd-new.gz`
(from step b — original + tools, no rootfs). *(Don't boot yet — stage the firmware in 1.2 first.)*
**→ continue at [1.2 — Qualcomm firmware](#12--qualcomm-firmware-windows--usb-data-partition), then [1.3 — the installer shell](#13--at-the-installer-shell-partition--extract--chroot--boot).**
(Prefer a single flash with no Windows-side partitioning? See the **1.1-ALT** alternative
below; otherwise skip it and continue to 1.2.)

### 1.1-ALT — Build the whole 2-partition image in WSL (one flash, no Windows partitioning) 🧪 WSL BUILD VERIFIED / BOOT PENDING

> 🧪 **Built and verified in WSL; not yet booted on the Yoga.** The image-assembly steps below
> were run end-to-end and produce a valid 2-partition image (both partitions read back
> correctly). What's still unconfirmed is the *boot* on the Yoga. Treat the flash-and-boot as
> the remaining unknown, not the build.

**Why you'd want it:** 1.1(c) has you flash, then hand-create a second FAT32 partition in
**Windows** Disk Management to carry the rootfs — fiddly, and where a stray `diskpart` can wipe
the wrong disk. This alternative does **everything in WSL against the image *file*** and hands
you a finished 2-partition image to flash **once** — nothing to partition or resize on the
Windows side afterward. Same on-USB layout as 1.1(c) (slim initrd on p1, rootfs on a second
partition p2), just assembled in one place.

> ⚠️ **The one trap this avoids — don't use loop devices in WSL.** WSL 2's kernel doesn't
> implement the geometry ioctl (`HDIO_GETGEO`) on **loop partitions** (`/dev/loopNpX`). So
> `mount -t vfat`, `fatresize`, and mtools' `mformat` all **fail** there (you'll see *"Could
> not get geometry … Inappropriate ioctl for device"*, false *"Disk full"*, or *"short
> write"*). The fix is to **never attach a loop device**: operate on the image **file** with
> `sfdisk` (partition table), `mkfs.vfat` on a scratch file (format), `dd` (splice), and
> `mtools`' `partition=` drives (copy) — none of those call that ioctl. Also note the Codelinaro
> image is **MBR (msdos), not GPT** — use `sfdisk`/`fdisk`, *not* `sgdisk` (it refuses: *"Non-GPT
> disk; not saving changes"*).

Do it in **WSL (Debian arm64)**. Needs `sfdisk`/`fdisk` (util-linux), `dosfstools`
(`mkfs.vfat`), `mtools`, `cpio`, `gzip`. Prereq: the `fdisk`+`mkfs.ext4` bundle from **1.1(a)**
at `~/initrd-tools/opt`, and the rootfs tarball downloaded to `~`.
```bash
# 0) Fresh COPY of the downloaded Codelinaro image, + headroom for a data partition.
#    (Confirm the original is < 2560M first, else raise the truncate size — truncate SHRINKS
#    if the target is smaller, which would corrupt p1.)
cd ~
cp /mnt/c/Users/<you>/Downloads/<codelinaro>.img ~/usb.img
ls -l ~/usb.img
truncate -s 2560M ~/usb.img
sudo apt-get install -y util-linux mtools dosfstools

# 1) Append p2 after p1 on the MBR table: default start (auto-aligned), fill the rest,
#    type c = W95 FAT32 (LBA). sfdisk places it correctly so there's no offset to guess.
echo ',,c' | sfdisk --append ~/usb.img

# 2) Read back p2's real start SECTOR (deterministic — used for the splice below)
sfdisk -d ~/usb.img
START=$(sfdisk -d ~/usb.img | awk -F'[ ,=]+' '/img2 :/{print $4}')
echo "p2 start sector: $START"                 # sanity: non-empty, ~600000+

# 3) Build p2's FAT filesystem as a SEPARATE scratch file (mkfs.vfat is rock-solid on a plain
#    file; it can't format "partition 2 inside another file", hence the standalone image).
#    Then load the rootfs tarball into it.
truncate -s 1024M ~/p2.img
mkfs.vfat -F32 -n ARCHDATA ~/p2.img
MTOOLS_SKIP_CHECK=1 mcopy -i ~/p2.img ~/ArchLinuxARM-aarch64-latest.tar.gz ::
MTOOLS_SKIP_CHECK=1 mdir  -i ~/p2.img ::        # tarball listed

# 4) Splice that filesystem INTO usb.img at p2's start (conv=notrunc = don't shrink usb.img).
#    p2.img is scratch — delete it after this.
dd if=~/p2.img of=~/usb.img bs=512 seek=$START conv=notrunc status=progress
rm -f ~/p2.img

# 5) p1: swap in a SLIM initrd = pristine original + the tools bundle (~130-150 MB, fits the
#    ~300 MB boot partition). mtools reads the MBR partition table from the file, no loop device.
printf 'drive z: file="%s" partition=1\ndrive y: file="%s" partition=2\n' \
  "$HOME/usb.img" "$HOME/usb.img" > ~/.mtoolsrc
MTOOLS_SKIP_CHECK=1 mcopy z:initrd.gz ~/initrd.orig.gz
rm -rf ~/initrd-slim && mkdir ~/initrd-slim && cd ~/initrd-slim
sudo sh -c 'zcat ~/initrd.orig.gz | cpio -idmv'        # confirm gzip first if unsure: file ~/initrd.orig.gz
sudo cp -a ~/initrd-tools/opt .
sudo sh -c 'find . | cpio -o -H newc | gzip > ~/initrd.slim.gz'
ls -lh ~/initrd.slim.gz                         # expect ~130-150 MB, NOT ~900
MTOOLS_SKIP_CHECK=1 mdel  z:initrd.gz
MTOOLS_SKIP_CHECK=1 mcopy ~/initrd.slim.gz z:initrd.gz

# 6) Verify BOTH partitions read back, then copy out to flash
MTOOLS_SKIP_CHECK=1 mdir z:                     # slim initrd on p1
MTOOLS_SKIP_CHECK=1 mdir y:                     # tarball on p2 (proves splice + table agree)
cp ~/usb.img /mnt/c/Users/<you>/Downloads/usb-arch-ready.img
```
Rufus DD-flash `usb-arch-ready.img` (accept DD/MBR — expected). At the installer shell the
rootfs is on the **second partition** (`LABEL=ARCHDATA`): mount it before extracting, i.e.
`mount /dev/disk/by-label/ARCHDATA /mnt/data` then `tar -xpf /mnt/data/…tar.gz -C /mnt` (see 1.3).

> **Notes / gotchas learned the hard way:**
> - **Two files on purpose.** `usb.img` = the whole disk image you flash; `p2.img` = a throwaway
>   holding only p2's filesystem, spliced in with `dd` then deleted. They are not the same file.
> - **Don't bake the rootfs into the initrd.** A rootfs-in-initrd balloons to ~900 MB, won't fit
>   the boot partition, and loads *entirely into RAM* at boot. Keeping it on p2 sidesteps both.
> - **If `mdir y:` errors** (older mtools not parsing the entry), use an explicit offset instead
>   of `partition=2`: `drive y: file="$HOME/usb.img" offset=$((START*512))`.
> - **If `mkfs.vfat` isn't found**, install `dosfstools`. **If `sfdisk`'s `START` parses empty**,
>   read it from `sfdisk -d ~/usb.img` by hand (the `start=` value on the `usb.img2` line).

### 1.2 — Qualcomm firmware (Windows → USB `DATA` partition)

Linux needs Qualcomm's firmware blobs (DSP, WLAN, camera, …) that ship **only inside Windows**.
Pull them from the Windows DriverStore and stage them on the USB's `DATA` partition — the one
you made in **1.1(c)**, right next to the rootfs tarball. `DATA` is just the **courier**: the
files don't belong in the boot partition or the initrd (the installer doesn't need them to
run), and **1.3 copies them onto the NVMe** at install time.

**Collect + stage in one shot.** From an **elevated** PowerShell, point the helper at the
`DATA` drive letter (`F:` here):
```powershell
.\copy-qcom-firmware.ps1 -Destination F:\
```
It recurses `C:\Windows\System32\DriverStore\FileRepository\` for `*.mbn`, `*.jsn`, and
`*dtbs.elf`, copies them to `F:\qcom-firmware\` (preserving source subfolders so same-named
blobs don't collide), and writes a `MANIFEST.csv`. Prefer to do it by hand? Grab those three
patterns from `…\FileRepository\*\` yourself — same files.

After it runs, `DATA` carries both halves the installer needs:
```
F:\
├── ArchLinuxARM-aarch64-latest.tar.gz     (rootfs, from 1.1c)
└── qcom-firmware\   (+ MANIFEST.csv)       (firmware, this step)
```

**Gotchas worth knowing:**
- **DSP device-tree naming:** it ships as **`adsp_dtbs.elf` / `cdsp_dtbs.elf`**, *not* a literal
  `dtbs.elf` — the script matches `*dtbs.elf` for exactly this reason.
- **Wi-Fi firmware is also `.elf`** (`bdwlan*.elf`, `phy_ucode*.elf`). Add `*.elf` to the
  script's patterns if you want the WLAN/camera blobs too.
- **Run elevated** — some DriverStore subtrees are ACL'd and get skipped otherwise.
- **1.1-ALT path:** the second partition is labeled `ARCHDATA` (not `DATA`) but carries the same
  cargo — put `qcom-firmware/` alongside the rootfs tarball on it (`mcopy -i ~/p2.img -s
  ~/qcom-firmware ::` before the splice, or copy it on later) — then copy it onto the NVMe in 1.3
  the same way.

The *final* placement into `/lib/firmware/qcom/x1e80100/<VENDOR>/<MODEL>/` happens in **1.3**:
the exact `<VENDOR>/<MODEL>` leaf is dictated by the DTB, so it's done there alongside the DTB.

### 1.3 — At the installer shell: partition → extract → chroot → boot

> **You arrive here after 1.1 + 1.2** (or 1.1-ALT + 1.2). Flash the USB, boot it (F12), and you
> land at the Debian installer's initrd shell. Everything in 1.3 is identical regardless of
> which prep you used — this is the actual Arch install. (The *rootfs source* is a labeled second
> partition either way: 1.1(c) → `LABEL=DATA`; 1.1-ALT → `LABEL=ARCHDATA`. Mount it, then extract.)

> ⚠️ **This is an outline, not a verified transcript.** joske's gist is self-described as
> *"from memory, may be incomplete,"* and the exact **kernel / firmware / DTB / bootloader**
> steps are device-specific — take those from the gist **and** kuruczgy's config, and verify
> against current state. The *generic* Arch-ARM steps below are safe to follow literally.
>
> ⚠️ **Dual-boot safety:** the Yoga already has a Windows **EFI System Partition (ESP)** and
> Windows partitions. **Reuse** the existing ESP for `/boot` — do **NOT** `mkfs` it, and never
> touch the Windows partitions. Format **only** your new Linux root. One wrong `mkfs`/`fdisk`
> write here can destroy Windows.

**Recommended layout & "best options" (dual-boot, no wipe).** You only *add* to the disk:

| Partition | What | Recommendation |
|---|---|---|
| **ESP** | existing Windows EFI System Partition (~100–300 MB FAT) | **Reuse**, mount at `/boot`, never `mkfs`. If it's cramped, make a separate `/boot` (below). |
| **`/boot`** | *(optional)* new ~1 GB FAT32 | Only if the Windows ESP is too small for a kernel+initrd/UKI. Otherwise skip and use the ESP. |
| **root `/`** | your new partition in the freed space | **ext4** = simplest, boots fastest (what your 1.1a bundle formats). **Btrfs** = swarmarchy's intended scheme (Snapper rollbacks + the hibernation swapfile). |
| **swap** | — | **None. Don't make a swap partition.** The swarmarchy layer sets up **zram** automatically (see the swap note below). |

- **ext4 vs Btrfs:** start with **ext4** to prove the hardware boots (your initrd already has
  `mkfs.ext4`). Want Snapper snapshots later? Use **Btrfs** — but add `btrfs-progs` to the
  initrd the same way you added `e2fsprogs` in **1.1(a)**, and it pairs with the **Limine**
  bootloader. Don't gate your first boot on it.
- **LUKS encryption:** swarmarchy's target is LUKS+Btrfs+Limine, but LUKS adds moving parts to
  an already-hard ARM bring-up. **Skip it for the first successful boot;** add on a reinstall
  once the hardware is proven.
- **No separate `/home`** for a laptop — one root keeps it simple.

> 💤 **Swap is the layer's job, not this step — so make no swap partition.** After Step 2,
> swarmarchy configures **zram** (compressed RAM swap: ½ RAM, capped 8 GB, zstd —
> `/etc/systemd/zram-generator.conf`) which the kernel uses before any disk swap. A disk
> swapfile is only for **hibernation**, which auto-skips where unsupported (expected on
> Snapdragon), so zram is effectively your swap. This is the modern "zram instead of disk
> swap" setup — you don't select it during the base install; the layer does it.

**a) Identify your disks/partitions FIRST — never guess device names:**
```sh
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,LABEL,MOUNTPOINT   # the whole picture, every disk
blkid                                                     # UUID + LABEL + TYPE per partition
fdisk -l /dev/nvme0n1 | grep -i 'EFI System'              # locate the Windows ESP (small FAT)
ls -l /dev/disk/by-label/                                 # confirm your DATA partition is here
ip link                                                   # wifi iface name (wlan0 / wlp...)
```
Read off the device names and pin them to variables so the destructive steps can't hit the
wrong disk:
```sh
NVME=/dev/nvme0n1        # INTERNAL drive (big, ~1 TB). The USB is a separate /dev/sdX (~8 GB)!
ESP=${NVME}p1            # EXISTING Windows EFI System Partition (from the `fdisk -l` line above)
# ROOT is set below, AFTER you create the new partition.
```
- **NVME** = internal drive. In `lsblk` the USB is the ~8 GB `/dev/sdX` — do not confuse them.
- **ESP** = the small (~100–300 MB) partition whose type is *EFI System*. It's Windows'; you
  reuse it, never format it.
- **DATA** = your rootfs carrier — reach it at `/dev/disk/by-label/DATA` (or the `vfat`/`LABEL=DATA`
  row in `lsblk`). *(1.1-ALT names it `ARCHDATA` — use `/dev/disk/by-label/ARCHDATA` instead.)*

**b) Generic Arch-ARM steps (same for any install):**
```sh
# --- networking (gist uses a 2nd TTY: Fn+Alt+F2, return with Fn+Alt+F1) ---
# from `ip link` above, note your wifi iface (e.g. wlan0); make /etc/wpa_supplicant.conf for
# your SSID, then bring up wifi + DHCP (exact invocation per the installer environment)

# --- partition: ADD a Linux root in the free space; REUSE the Windows ESP ($ESP) ---
/opt/tools/bin/fdisk.sh "$NVME"                # create ONE new root partition in the free space
lsblk "$NVME"                                  # re-read the table -> note the NEW partition number
ROOT=${NVME}p6                                 # <-- set to the partition you just created
/opt/tools/bin/mkfs.ext4 "$ROOT"               # format ONLY the new root — NEVER $ESP

# --- mount target + source, extract the rootfs INTO the target ---
mount "$ROOT" /mnt                             # new Arch root (target)
mkdir -p /mnt/boot && mount "$ESP" /mnt/boot   # EXISTING Windows ESP — mount only, do NOT mkfs
mkdir -p /mnt/data && mount /dev/disk/by-label/DATA /mnt/data   # 1.1-ALT: LABEL=ARCHDATA
tar -xpf /mnt/data/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt   # source -> target

# --- Qualcomm firmware -> target rootfs (staged on DATA in 1.2). It loads at
#     RUNTIME from the rootfs, so it lives in /mnt/lib/firmware, NOT the initrd. The
#     <VENDOR>/<MODEL> leaf is whatever the DTB's firmware-name asks for -- read it with:
#       dtc -I dtb -O dts <your.dtb> | grep firmware-name
DEST=/mnt/lib/firmware/qcom/x1e80100/<VENDOR>/<MODEL>
mkdir -p "$DEST"
find /mnt/data/qcom-firmware -type f \( -name '*.mbn' -o -name '*.jsn' -o -name '*dtbs.elf' \) \
     -exec cp {} "$DEST"/ \;         # flattens into the leaf; match names to what the DTB wants

# --- note UUIDs for fstab BEFORE chroot (vars don't survive the chroot) ---
blkid "$ROOT" "$ESP"                           # copy these UUIDs down for /etc/fstab

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
# write /etc/fstab from the UUIDs you noted (root -> /, ESP -> /boot vfat)
```

**c) Device-specific steps — DO NOT improvise; pull exact commands from the references:**
- **Kernel:** a Snapdragon-capable kernel — the gist/comments point to the **jhovold** branch
  (`wip/x1e80100-*`); kuruczgy's config is the authoritative kernel/quirks source.
- **Firmware:** already copied above (from `DATA` → `/mnt/lib/firmware/qcom/x1e80100/…`). Get
  the exact `<VENDOR>/<MODEL>` leaf + filenames from the DTB's `firmware-name`; after boot,
  `dmesg | grep -i firmware` names the precise path of anything still missing.
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
- the **Qualcomm firmware** from 1.2.

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

## Troubleshooting

### Flashed USB doesn't show up in Windows Explorer (no drive letter)

After Rufus DD-clones the Codelinaro image, the boot partition often **won't appear in
Explorer** and has **no drive letter**. This is expected — not a failed flash:

- The image tags its partition with MBR type byte **`0x83` (Linux)**, even though the
  filesystem inside is **FAT**. Windows' automount only auto-letters partitions tagged as
  *its own* types (`0x06`/`0x0b`/`0x0c`/`0x07`…), so it deliberately skips `0x83`.
  `Get-Volume` still lists it as a `FAT` volume — just with a blank `DriveLetter`.
- Disk Management's **Change Drive Letter and Paths… is greyed out** for this partition
  (Windows treats `0x83` as foreign). The CLI tools below override that.

**Fix — assign a letter from an *admin* PowerShell:**
```powershell
Get-Disk                                              # find the Kingston/USB disk number, e.g. 2
Get-Partition -DiskNumber 2                           # confirm the FAT partition number (usually 1)
Set-Partition -DiskNumber 2 -PartitionNumber 1 -NewDriveLetter E
```
or the same thing in `diskpart` (admin):
```
diskpart
select disk 2
select partition 1
assign letter=E
exit
```
`E:` then shows in Explorer. Non-destructive — no reformat, stays bootable. (`Set-Partition`
without admin fails with `Access denied`.)

**If the stick isn't visible to Windows at all** — not even in Disk Management — check it
isn't currently attached to WSL via **usbipd**, which removes it from Windows entirely:
```bash
"/mnt/c/Program Files/usbipd-win/usbipd.exe" list                  # STATE = Attached?
"/mnt/c/Program Files/usbipd-win/usbipd.exe" detach --busid <BUSID>
```

**Make it auto-mount on every future plug-in (optional).** Flip the type byte to FAT so
Windows automount handles it unconditionally — either `diskpart → select disk/partition →
set id=0c`, or from WSL `sudo sfdisk --part-type /dev/sdX 1 c`. Afterward it letters itself
like a normal stick. Revert with `set id=83` / `sfdisk … 1 83` if the Qualcomm boot flow
objects to the changed type.

> **Why it "used to just work":** Windows remembers a volume→letter mapping in
> `HKLM\SYSTEM\MountedDevices`, keyed to the disk's 4-byte **MBR signature**. A raw DD flash
> writes the image's own signature, and `diskpart clean` erases the signature outright — both
> orphan the old mapping, so the letter must be (re)assigned. `clean` is also *not* how you
> grow a partition into free space — that's `extend` (or GParted); `clean` wipes the whole
> partition table.

## References
joske gist · kuruczgy NixOS config · Ubuntu Concept ISO · daily-driver writeup
(https://varunpriolkar.com/2025/07/daily-driving-an-arm-linux-laptop/) · remaining
ISO-build blockers in `swarmarchy-iso/BUILD-AARCH64.md`.
