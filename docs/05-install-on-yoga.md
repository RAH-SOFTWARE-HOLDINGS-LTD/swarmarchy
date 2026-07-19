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
(Prefer one flash with **no Windows-side partitioning and nothing to mount at the installer
shell**? See **1.1-ALT** below — it bakes the rootfs *and* firmware into the initrd on a single
enlarged boot partition. Otherwise skip it and continue to 1.2.)

### 1.1-ALT — Build ONE self-contained image in WSL (single partition, everything baked into the initrd) 🧪 WSL BUILD VERIFIED / BOOT PENDING

> 🧪 **Built and verified in WSL; not yet booted on the Yoga.** The assembly below was run
> end-to-end and produces a valid single-partition image (partition reads back, all payloads
> present). The remaining unknown is the *boot* on the Yoga, not the build.

**Why you'd want it — and why single-partition.** 1.1(c) flashes, then has you hand-create a
second partition in **Windows** Disk Management to carry the rootfs — fiddly, and the empirical
snag is that **the installer's minimal initrd could not mount that second partition** at the
shell. This alternative sidesteps mounting *anything*: it enlarges the Codelinaro image's own
**single FAT boot partition** and bakes the rootfs tarball **and** the Qualcomm firmware
**inside the initrd**. At the installer shell they're already sitting in RAM at `/root/` — no
mount, no `LABEL=`, no second partition. The only cost is a fat (~935 MB) initrd, which is why
the boot partition has to grow from ~300 MB to ~1.5 GB. It all loads into RAM at boot (have
≥ 4 GB free — the Yoga does).

> ⚠️ **The trap this avoids — don't use loop devices in WSL.** WSL 2's kernel doesn't implement
> the geometry ioctl (`HDIO_GETGEO`) on **loop partitions** (`/dev/loopNpX`), so `mount -t vfat`,
> `fatresize`, and mtools' `mformat` all **fail** (*"Could not get geometry … Inappropriate ioctl
> for device"*, false *"Disk full"*, *"short write"*). Everything below works on the image **file**
> — `sfdisk` (table), `mkfs.vfat` on a scratch file (format), `mtools` `@@offset` (read/write the
> FAT), `dd` (splice) — none call that ioctl, and **none need `sudo`** except the one initrd repack
> in step 1 (which does, to preserve the original initrd's `/dev` nodes). The Codelinaro image is
> **MBR (msdos), not GPT** — use `sfdisk`/`fdisk`, *not* `sgdisk`.

Do it in **WSL (Debian arm64)**. Needs `sfdisk`/`fdisk` (util-linux), `dosfstools` (`mkfs.vfat`),
`mtools`, `cpio`, `gzip`. Prereqs: the `fdisk`+`mkfs.ext4` bundle from **1.1(a)** at
`~/initrd-tools/opt`, the rootfs tarball at `~`, and (for the firmware) `~/qcom-firmware/` from
**1.2** (build that first, or drop the two firmware steps to add it later).

```bash
cd ~
sudo apt-get install -y util-linux mtools dosfstools cpio gzip
SRC=/mnt/c/Users/<you>/Downloads/<codelinaro>.img       # the DOWNLOADED image, left untouched

# 1) BAKE the fat initrd = original initrd + tools bundle + rootfs tarball. (sudo: the original
#    initrd has /dev nodes that only root can recreate on repack.) Point ../initrd.orig.gz at the
#    pristine initrd — pull it out of SRC's FAT with mtools if you don't already have it:
#      MTOOLS_SKIP_CHECK=1 mcopy -i "$SRC"@@$((2048*512)) ::/initrd.gz ~/initrd.orig.gz
rm -rf ~/initrd-baked && mkdir ~/initrd-baked && cd ~/initrd-baked
sudo sh -c 'zcat ~/initrd.orig.gz | cpio -idmv'         # confirm gzip first: file ~/initrd.orig.gz
sudo cp -a ~/initrd-tools/opt .                         # -> /opt/tools/{fdisk.sh,mkfs.ext4,...}
sudo cp ~/ArchLinuxARM-aarch64-latest.tar.gz root/      # -> /root/ArchLinuxARM-...tar.gz
sudo sh -c 'find . | cpio -o -H newc | gzip > ~/initrd.baked.gz'
cd ~; ls -lh ~/initrd.baked.gz                          # ~905 MB

# 2) APPEND the Qualcomm firmware as a SECOND gzip'd-cpio segment (the kernel's initramfs loader
#    concatenates archives — same mechanism as CPU microcode). No sudo, base stays byte-identical.
rm -rf ~/fwseg && mkdir -p ~/fwseg/root && cp -a ~/qcom-firmware ~/fwseg/root/
( cd ~/fwseg && find root | cpio -o -H newc 2>/dev/null | gzip ) > ~/fw.cpio.gz
cat ~/initrd.baked.gz ~/fw.cpio.gz > ~/initrd.final.gz   # -> ~935 MB
# verify all three payloads survived (cpio -t stops at the 1st trailer, so grep the raw stream):
zcat ~/initrd.final.gz | grep -a -c 'qcom-firmware/MANIFEST.csv'   # expect 1
zcat ~/initrd.final.gz | cpio -t 2>/dev/null | grep -E 'opt/tools/bin/mkfs.ext4|root/ArchLinuxARM'

# 3) EXTRACT the Codelinaro boot tree from SRC's single FAT partition (starts at sector 2048),
#    then swap in the fat initrd. mtools @@offset reads the FAT straight out of the file.
O=$((2048*512))
rm -rf ~/p1extract && mkdir ~/p1extract
MTOOLS_SKIP_CHECK=1 mcopy -s -i "$SRC"@@$O "::/*" ~/p1extract/
cp ~/initrd.final.gz ~/p1extract/initrd.gz              # grub loads /linux + /initrd.gz by name

# 4) Rebuild that partition as a LARGER FAT (scratch file), copy the tree back in.
rm -f ~/p1.img
truncate -s 1500M ~/p1.img
mkfs.vfat -F32 -n BOOT ~/p1.img
( cd ~/p1extract && MTOOLS_SKIP_CHECK=1 mcopy -s -i ~/p1.img boot boot.cat dtb EFI gtk initrd.gz linux :: )
MTOOLS_SKIP_CHECK=1 mdir -i ~/p1.img ::                 # sanity: 7 entries, ~450 MB free

# 5) ASSEMBLE the whole-disk image: one MBR partition (type 83, bootable) starting at sector 2048,
#    then splice the FAT in. No loop device, no sudo.
rm -f ~/usb-single.img
SECT=$(( $(stat -c%s ~/p1.img) / 512 ))
truncate -s $(( (2048 + SECT) * 512 )) ~/usb-single.img
printf 'label: dos\nunit: sectors\nstart=2048, size=%s, type=83, bootable\n' "$SECT" | sfdisk ~/usb-single.img
dd if=~/p1.img of=~/usb-single.img bs=512 seek=2048 conv=notrunc status=progress

# 6) VERIFY the partition reads back, copy out to flash, clean up scratch.
MTOOLS_SKIP_CHECK=1 mdir -i ~/usb-single.img@@$O ::      # linux + initrd.gz (~980 MB) present
cp ~/usb-single.img /mnt/c/Users/<you>/Downloads/usb-single.img
rm -f ~/fw.cpio.gz; rm -rf ~/fwseg ~/initrd-baked
```
Rufus DD-flash `usb-single.img` (accept DD/MBR — expected). At the installer shell **nothing
needs mounting** — the rootfs and firmware are already in the initramfs at `/root/`:
```sh
tar -xpf /root/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt   # after you mkfs+mount the NVMe root
cp -r /root/qcom-firmware /mnt/root/                        # firmware carrier -> onto the NVMe (see 1.3)
```

> **Notes / gotchas learned the hard way:**
> - **Everything's in the initrd, nothing on a data partition.** Chose single-partition precisely
>   because the minimal installer initrd could **not** mount a second partition at the shell. The
>   price is a ~935 MB initrd that loads wholly into RAM — fine on a laptop with GBs free.
> - **`cpio -t` only lists the FIRST segment.** After concatenating (step 2) it stops at the first
>   `TRAILER!!!`, so the firmware won't show — that's normal. Verify with `zcat … | grep -a`
>   against the decompressed stream instead; the kernel unpacks *all* segments.
> - **The FAT must be big enough for the fat initrd.** ~935 MB initrd + 14 MB kernel + boot files
>   ⇒ 1500 MB FAT leaves ~450 MB slack. If you skip the firmware (initrd ~905 MB) 1280 MB is plenty.
> - **`truncate` on `~/p1.img`/`~/usb-single.img` is safe** (fresh scratch files); never `truncate`
>   the SRC image — shrinking corrupts it. SRC is only ever *read* here.
> - **If `mkfs.vfat` isn't found**, install `dosfstools`. **If `mcopy -s "::/*"` misses dotfiles**,
>   the Codelinaro tree has none at root — the 7 named entries in step 4 are the whole payload.

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
- **1.1-ALT path (single partition):** there's no data partition — `qcom-firmware/` is **baked
  into the initrd** (1.1-ALT step 2, appended as a second cpio segment). Stage it at
  `~/qcom-firmware/` in WSL *before* running 1.1-ALT so it gets folded in; at the installer shell
  it's at `/root/qcom-firmware/`, and 1.3 copies it onto the NVMe from there.

The *final* placement into `/lib/firmware/qcom/x1e80100/<VENDOR>/<MODEL>/` happens in **1.3**:
the exact `<VENDOR>/<MODEL>` leaf is dictated by the DTB, so it's done there alongside the DTB.

### 1.3 — At the installer shell: partition → extract → chroot → boot

> **You arrive here after 1.1 + 1.2** (or 1.1-ALT + 1.2). Flash the USB, boot it (F12), and you
> land at the Debian installer's initrd shell. Everything in 1.3 is identical regardless of
> which prep you used — this is the actual Arch install. (The *rootfs source* differs by prep:
> 1.1(c) → a labeled second partition `LABEL=DATA` you **mount, then extract**; 1.1-ALT → already
> in the initramfs at `/root/`, **no mount** — just `tar -xpf /root/…tar.gz`.)

> ⚠️ **This is an outline, not a verified transcript.** joske's gist is self-described as
> *"from memory, may be incomplete,"* and the exact **kernel / firmware / DTB / bootloader**
> steps are device-specific — take those from the gist **and** kuruczgy's config, and verify
> against current state. The *generic* Arch-ARM steps below are safe to follow literally.
>
> ⚠️ **Dual-boot safety:** the Yoga already has a Windows **EFI System Partition (ESP)** and
> Windows partitions. **Reuse** the existing ESP, mounting it at **`/boot/efi`** (never at
> `/boot`) — do **NOT** `mkfs` it, and never touch the Windows partitions. Format **only** your
> new Linux root. One wrong `mkfs`/`fdisk` write here can destroy Windows.
>
> 🪤 **The ESP-fills-up trap (mount it at `/boot/efi`, NOT `/boot`).** The Windows ESP is tiny
> (~100–300 MB). If you mount it at `/boot`, pacman writes the **kernel + initramfs + DTBs**
> (tens of MB, and a fresh copy every kernel update) straight onto it and it fills instantly —
> then you're hand-deleting files to make room. Instead leave `/boot` as a plain **directory on
> your ext4 root** (roomy) and mount the ESP at **`/boot/efi`**, where only the few-MB GRUB stub
> lives. Do this and there is **nothing to clean up.**

**Recommended layout & "best options" (dual-boot, no wipe).** You only *add* to the disk:

| Partition | What | Recommendation |
|---|---|---|
| **ESP** | existing Windows EFI System Partition (~100–300 MB FAT) | **Reuse**, mount at **`/boot/efi`** (NOT `/boot`), never `mkfs`. Only the GRUB stub goes here. |
| **`/boot`** | a plain **directory on your ext4 root** — *not* a partition | Leave it on root. Kernel + initramfs + DTBs live here so they never touch the tiny ESP. Don't make a separate FAT `/boot`. |
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
ls -l /dev/disk/by-label/                                 # 1.1(c): confirm your DATA partition is here
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
  row in `lsblk`). *(**1.1-ALT users: skip this** — there's no DATA partition; the rootfs and
  firmware are already in the initramfs at `/root/`. Ignore the DATA mount below.)*

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

# --- mount target, extract the rootfs INTO it ---
mount "$ROOT" /mnt                                       # new Arch root (target)
# ESP goes at /boot/efi ONLY (never /boot). /boot itself stays a dir on the ext4 root, so the
# kernel/initrd/DTBs land on roomy ext4 and the tiny ESP only ever holds the GRUB stub.
mkdir -p /mnt/boot/efi && mount "$ESP" /mnt/boot/efi     # EXISTING Windows ESP — mount only, do NOT mkfs
# 1.1(c): mount the DATA carrier; its tarball path is /mnt/data/... :
mkdir -p /mnt/data && mount /dev/disk/by-label/DATA /mnt/data
tar -xpf /mnt/data/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt   # source -> target
# 1.1-ALT: NO mount — the tarball is already in the initramfs, so instead run:
#   tar -xpf /root/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt

# --- Qualcomm firmware -> target rootfs. It loads at RUNTIME from the rootfs, so it lives in
#     /mnt/lib/firmware, NOT the initrd. Source dir: 1.1(c) → /mnt/data/qcom-firmware ;
#     1.1-ALT → /root/qcom-firmware (already in the initramfs). The <VENDOR>/<MODEL> leaf is
#     whatever the DTB's firmware-name asks for -- read it with:
#       dtc -I dtb -O dts <your.dtb> | grep firmware-name
FW=/mnt/data/qcom-firmware                      # 1.1-ALT: FW=/root/qcom-firmware
DEST=/mnt/lib/firmware/qcom/x1e80100/<VENDOR>/<MODEL>
mkdir -p "$DEST"
find "$FW" -type f \( -name '*.mbn' -o -name '*.jsn' -o -name '*dtbs.elf' \) \
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
# write /etc/fstab from the UUIDs you noted. TWO lines only:
#   UUID=<root-uuid>  /          ext4  defaults          0 1
#   UUID=<esp-uuid>   /boot/efi  vfat  defaults,noatime  0 2
# NOTE: /boot has NO fstab line -- it's a dir on root. The ESP is vfat (NOT ext4), at /boot/efi.
```

**c) Kernel + firmware — still in the chroot:**
```sh
pacman -S linux-aarch64 linux-firmware mkinitcpio grub efibootmgr networkmanager sudo
```
Installing `linux-aarch64` **populates `/boot` for you** — the kernel `Image`, `initramfs-linux.img`,
and the `dtbs/` tree all land on the ext4 `/boot`. Verify (no manual copy from the USB needed):
```sh
ls /boot                                # Image, initramfs-linux.img, dtbs/
ls /boot/dtbs/qcom/ | grep yoga         # x1e80100-lenovo-yoga-slim7x.dtb (+ -el2 variant)
```
- **Firmware:** already copied above into `/mnt/lib/firmware/qcom/x1e80100/…`. Get the exact
  `<VENDOR>/<MODEL>` leaf + filenames from the DTB's `firmware-name`; after boot,
  `dmesg | grep -i firmware` names the precise path of anything still missing.
- **DTB:** `qcom/x1e80100-lenovo-yoga-slim7x.dtb`.
- **Graphics:** software rendering works out of the box; for real acceleration use Mesa **turnip**
  (or the **zink** path until turnip is solid). Not required to reach a first boot.
- **Better kernel later:** for solid GPU/peripherals the community points to the **jhovold**
  branch (`wip/x1e80100-*`); kuruczgy's config is the authoritative kernel/quirks source. The
  stock `linux-aarch64` is enough to boot first.

> Authoritative sources for the device-specific commands: **joske's gist** (the flow) and
> **kuruczgy's x1e-nixos-config** (kernel/firmware/DTB/quirks) — both linked at the top of Step 1.

### 1.4 — Bootloader: GRUB (kept deliberately simple)

Two quirks drive the whole approach — internalize them and the rest is short:

1. **The installer has no EFI runtime services** — `/sys/firmware/efi/efivars` is empty, so
   `efibootmgr` **cannot register a boot entry from here (or the chroot).** Don't fight it. You
   install GRUB to the firmware's *fallback* path now, and register a proper named entry **after
   first boot**, from the running system, where efivars work. *(That's the "do it outside the
   chroot" part — it's not optional cleverness, it's the only place `efibootmgr` works.)*
2. **`grub-mkconfig` doesn't emit a `devicetree` line for aarch64**, and the Yoga won't boot
   without its DTB — so you add one custom menu entry by hand.

**In the chroot** — install GRUB to the ESP's fallback path (`EFI/BOOT/BOOTAA64.EFI`):
```sh
grub-install --target=arm64-efi --efi-directory=/boot/efi --removable --no-nvram
```
- `--efi-directory=/boot/efi` — the ESP. The stub is a few MB, so the ESP stays roomy.
- `--removable` — writes the generic `EFI/BOOT/BOOTAA64.EFI` the firmware boots by default, so
  you don't need an NVRAM entry just to get going.
- `--no-nvram` — skips the `efibootmgr` write that would fail in the installer.

Add the DTB entry. Grab the **root** UUID, then write `/etc/grub.d/40_custom` (paste the UUID in):
```sh
blkid -s UUID -o value "$ROOT"          # copy this UUID into <ROOT-UUID> below
cat > /etc/grub.d/40_custom <<'EOF'
#!/bin/sh
exec tail -n +3 $0
menuentry "Arch Linux ARM (Yoga Slim 7x)" {
    insmod ext2
    search --no-floppy --set=root --file /boot/Image
    linux /boot/Image root=UUID=<ROOT-UUID> rw pd_ignore_unused clk_ignore_unused fw_devlink=off efi=novamap cma=128M rootwait loglevel=7
    initrd /boot/initramfs-linux.img
    devicetree /boot/dtbs/qcom/x1e80100-lenovo-yoga-slim7x.dtb
}
EOF
chmod +x /etc/grub.d/40_custom
grub-mkconfig -o /boot/grub/grub.cfg
grep -i devicetree /boot/grub/grub.cfg  # MUST print the devicetree line, else the DTB won't load
```

Then leave the chroot and reboot:
```sh
exit
umount -R /mnt
reboot                                  # remove the USB when it powers down
```

**First boot** (no `efibootmgr` yet): `F12` → pick the removable/USB-style entry for the internal
drive (that's the fallback `BOOTAA64.EFI` GRUB) → at the GRUB menu choose **"Arch Linux ARM (Yoga
Slim 7x)"** — the custom entry, *not* the auto-generated "Arch Linux" (which has no `devicetree`).
- If `F12` shows nothing new, register it once from **Windows** (elevated `cmd`):
  ```
  bcdedit /copy {bootmgr} /d "Arch"
  bcdedit /set {THAT-GUID} path \EFI\BOOT\BOOTAA64.EFI
  bcdedit /set {fwbootmgr} displayorder {THAT-GUID} /addfirst
  ```
  (PowerShell: quote every brace, e.g. `'{bootmgr}'`.)

**Once you're logged into Arch** — efivars now work, so give yourself a clean named boot entry.
This is the step that **can't** run in the chroot:
```sh
sudo efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Arch Linux" -l '\EFI\BOOT\BOOTAA64.EFI'
```
`F12` will then list **Arch Linux** directly, alongside **Windows Boot Manager** (untouched).

> **Black screen after selecting Arch?** That's the GPU firmware, not a broken install. Press `e`
> in GRUB and add `nomodeset` to the `linux` line to reach a text console and confirm the base is
> good; fix graphics later (turnip/jhovold kernel).

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
