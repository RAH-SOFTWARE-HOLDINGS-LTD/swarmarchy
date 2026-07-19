# Path A — Install swarmarchy on the Yoga (recommended)

> **Read this first.** swarmarchy is a **layer, not an OS** — it's applied *on top of* an
> existing Arch install. You are **not** building a bootable USB (that's Path B / `06`, and the
> aarch64 installer ISO isn't buildable yet).

Path A is two moves:

1. Get plain **Arch Linux ARM** booting on the Yoga (**Step 1** — the hard part).
2. Run one command to apply swarmarchy (**Step 2** — the easy part).

> ⚠️ **The hard, risky part is Step 1** — booting Linux on a Snapdragon X Elite. That's generic
> device bring-up, *not* a swarmarchy thing; the community already solved it, so you follow their
> guide.

---

## Step 0 — Windows prep (dual-boot, no wipe)

Do all of this **from Windows, before touching partitions:**

1. Back up your **BitLocker recovery key**
   - suspend BitLocker too if you can — otherwise repartitioning can lock you out of Windows
2. **Shrink the Windows partition** (Disk Management → *Shrink Volume*) to free space for Linux
   - leave the Windows + EFI partitions intact — this is dual-boot, no wipe
3. In **UEFI/BIOS**, disable **Secure Boot**

- **Qualcomm firmware is a later step, not here.** Linux needs Qualcomm's firmware blobs, which
  live only inside Windows. That's its own step ([1.2](#12--qualcomm-firmware-windows--usb-data-partition));
  it rides on the USB's `DATA` partition you create in 1.1.

## Step 1 — Get bare Arch Linux ARM booting ⚠️ (the hard part)

Follow the proven guide, don't improvise. References:

- **Primary — joske's gist** (Arch ARM on this exact laptop):
  https://gist.github.com/joske/52be3f1e5d0239706cd5a4252606644b
- **Reference — kuruczgy's NixOS config** (authoritative kernel/firmware/quirks list):
  https://github.com/kuruczgy/x1e-nixos-config
- **Optional warm-up:** boot Ubuntu's "Concept" arm64 ISO first to confirm the hardware works

### 1.1 — Prep the installer USB (the part joske's gist hand-waves)

- joske boots the **Codelinaro Debian-12 installer image**, then at its initrd shell uses it to
  install *Arch* instead.
- The gist leaves two lines as an exercise, with no commands:

> *"unpack the initrd and add this tarball … also add some tools like mkfs.ext4 and fdisk (I
> downloaded debian 12 versions and unpacked the necessary libs and binaries)"*

- Do the below on a **Debian 12 `arm64` box** (WSL on a Windows-on-ARM machine is ideal — the tools
  then version-match the installer's glibc).

**a) Build a self-contained `fdisk` + `mkfs.ext4` bundle.**
  - binaries + their `.so` deps + the dynamic loader, so they don't depend on the busybox initrd's libc
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

**b) Unpack the initrd, inject the tools, repack.**
  - an initrd is a gzip'd cpio archive; do it as root so ownership/`/dev` nodes survive
  - point `../initrd.gz` at the untouched initrd from the Codelinaro image
```bash
mkdir -p ~/initrd-tools/initrd-work && cd ~/initrd-tools/initrd-work
file ../initrd.gz                                   # confirm compression (gzip here)
sudo sh -c 'zcat ../initrd.gz | cpio -idmv'         # unpack the ORIGINAL into initrd-work/
sudo cp -a ~/initrd-tools/opt .                     # inject /opt/tools ONLY (no rootfs!)
sudo sh -c 'find . | cpio -o -H newc | gzip > ../initrd-new.gz'  # repack (~130-140 MB)
```
  - zstd/xz/lz4 original → swap `zcat`/`gzip` for `zstd`/`xz --check=crc32`/`lz4`
  - at the initrd shell on the Yoga you then run `/opt/tools/bin/fdisk.sh /dev/nvme0n1` and
    `/opt/tools/bin/mkfs.ext4 /dev/nvme0n1pN` — the wrappers handle the loader/lib path

> ⚠️ **Do NOT extract the Arch rootfs tarball *into* the initrd** (despite the gist's wording).
> - the Codelinaro image is a **raw disk image**: Rufus can only DD-clone it (partition scheme
>   greyed out to **MBR**, no ISO-mode), so its boot partition is a fixed **~300 MB**
> - the stock initrd is already **127 MB**; add the rootfs and it balloons to **~900 MB** — the
>   initrd (which must live on the boot partition, and loads entirely into RAM) can't fit, and the
>   copy dies with `Input/output error` (= disk full)
> - the initrd loads wholly into RAM at boot, so a 900 MB one wastes ~900 MB of RAM
> - **Fix:** keep the initrd small (original + tools ≈ 130–140 MB, fits the 300 MB boot partition)
>   and carry the rootfs on a *separate* partition you mount at install time

**c) Carry the rootfs on a second FAT32 partition (not inside the initrd).**
  - after Rufus DD-flashes the image (accept DD/MBR — expected), use Windows **Disk Management** to
    create a **second FAT32 partition** in the leftover unallocated space, label it `DATA`
    - FAT32, not NTFS — the minimal initrd has no NTFS driver, and the ~180 MB tarball is < 4 GB
  - in WSL, download the tarball and copy it on (swap `F:` for the DATA partition's real drive letter):
```bash
cd ~ && wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz

sudo mkdir -p /mnt/data
sudo mount -t drvfs F: /mnt/data            # F: = the DATA partition's letter
cp ~/ArchLinuxARM-aarch64-latest.tar.gz /mnt/data/    # copy the .tar.gz AS-IS, don't unpack
sync && ls -lah /mnt/data/
```
  - you'll add the Qualcomm firmware to this same `DATA` partition next, in 1.2
  - no drive letter? Disk Management → right-click the partition → *Change Drive Letter and Paths* →
    *Add* (if greyed out, see **Troubleshooting**)

- Finally, overwrite the boot partition's `initrd.gz` with your rebuilt `initrd-new.gz` (from step b
  — original + tools, no rootfs).
  - don't boot yet — stage the firmware in 1.2 first
- **→ continue at [1.2 — Qualcomm firmware](#12--qualcomm-firmware-windows--usb-data-partition),
  then [1.3 — the installer shell](#13--at-the-installer-shell-partition--extract--chroot).**
- Prefer one flash with no Windows-side partitioning and nothing to mount at the shell? See
  **1.1-ALT** — it bakes the rootfs *and* firmware into the initrd on a single enlarged boot
  partition. Otherwise skip it and continue to 1.2.

### 1.1-ALT — Build ONE self-contained image in WSL (single partition) 🧪 WSL BUILD VERIFIED / BOOT PENDING

> 🧪 **Built and verified in WSL; not yet booted on the Yoga.** The assembly below was run
> end-to-end and produces a valid single-partition image (partition reads back, all payloads
> present). The remaining unknown is the *boot* on the Yoga, not the build.

Why single-partition:

- 1.1(c) makes you hand-create a second partition in Windows to carry the rootfs — fiddly, and the
  empirical snag is the **installer's minimal initrd could not mount that second partition**.
- This sidesteps mounting *anything*: it enlarges the image's own **single FAT boot partition** and
  bakes the rootfs tarball **and** the Qualcomm firmware **inside the initrd**. At the shell they're
  in RAM at `/root/` — no mount, no `LABEL=`, no second partition.
- Cost: a fat (~935 MB) initrd, so the boot partition grows from ~300 MB to ~1.5 GB. It loads into
  RAM at boot (have ≥ 4 GB free — the Yoga does).

> ⚠️ **The trap this avoids — don't use loop devices in WSL.** WSL 2's kernel doesn't implement the
> geometry ioctl (`HDIO_GETGEO`) on **loop partitions** (`/dev/loopNpX`), so `mount -t vfat`,
> `fatresize`, and mtools' `mformat` all **fail** (*"Could not get geometry … Inappropriate ioctl
> for device"*, false *"Disk full"*, *"short write"*). Everything below works on the image **file** —
> `sfdisk` (table), `mkfs.vfat` on a scratch file (format), `mtools` `@@offset` (FAT), `dd` (splice) —
> none call that ioctl, and **none need `sudo`** except the one initrd repack in step 1. The image is
> **MBR (msdos), not GPT** — use `sfdisk`/`fdisk`, *not* `sgdisk`.

Prereqs (in **WSL, Debian arm64**):

- `sfdisk`/`fdisk` (util-linux), `dosfstools` (`mkfs.vfat`), `mtools`, `cpio`, `gzip`
- the `fdisk`+`mkfs.ext4` bundle from **1.1(a)** at `~/initrd-tools/opt`
- the rootfs tarball at `~`
- for the firmware: `~/qcom-firmware/` from **1.2** (build that first, or drop the two firmware
  steps and add it later)

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

- Rufus DD-flash `usb-single.img` (accept DD/MBR — expected).
- At the installer shell **nothing needs mounting** — the rootfs and firmware are in the initramfs
  at `/root/`:
```sh
tar -xpf /root/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt   # after you mkfs+mount the NVMe root
cp -r /root/qcom-firmware /mnt/root/                        # firmware carrier -> onto the NVMe (see 1.3)
```

> **Notes / gotchas learned the hard way:**
> - **Everything's in the initrd, nothing on a data partition** — chose single-partition because the
>   minimal installer initrd could *not* mount a second partition. Price: ~935 MB initrd wholly in RAM.
> - **`cpio -t` only lists the FIRST segment** — after concatenating (step 2) it stops at the first
>   `TRAILER!!!`, so the firmware won't show. Verify with `zcat … | grep -a` instead; the kernel
>   unpacks *all* segments.
> - **The FAT must fit the fat initrd** — ~935 MB initrd + 14 MB kernel ⇒ 1500 MB FAT leaves ~450 MB
>   slack. Skip the firmware (initrd ~905 MB) and 1280 MB is plenty.
> - **`truncate` on `~/p1.img`/`~/usb-single.img` is safe** (fresh scratch files); never `truncate`
>   the SRC image — shrinking corrupts it. SRC is only ever *read*.
> - **`mkfs.vfat` missing** → install `dosfstools`. **`mcopy -s "::/*"` misses dotfiles** → the
>   Codelinaro tree has none at root; the 7 named entries in step 4 are the whole payload.

### 1.2 — Qualcomm firmware (Windows → USB `DATA` partition)

- Linux needs Qualcomm's firmware blobs (DSP, WLAN, camera, …) that ship **only inside Windows**.
- `DATA` is just the **courier** — the files don't belong in the boot partition or initrd (the
  installer doesn't need them to run); **1.3 copies them onto the NVMe** at install time.

**a) Collect + stage in one shot** — from an **elevated** PowerShell, point the helper at the DATA
drive letter (`F:` here):
```powershell
.\copy-qcom-firmware.ps1 -Destination F:\
```
  - it recurses `C:\Windows\System32\DriverStore\FileRepository\` for `*.mbn`, `*.jsn`, `*dtbs.elf`,
    copies to `F:\qcom-firmware\` (preserving subfolders so same-named blobs don't collide), and
    writes a `MANIFEST.csv`
  - by hand? grab those three patterns from `…\FileRepository\*\` yourself — same files

- After it runs, `DATA` carries both halves the installer needs:
```
F:\
├── ArchLinuxARM-aarch64-latest.tar.gz     (rootfs, from 1.1c)
└── qcom-firmware\   (+ MANIFEST.csv)       (firmware, this step)
```

Gotchas:

- **DSP device-tree naming:** ships as `adsp_dtbs.elf` / `cdsp_dtbs.elf`, *not* literal `dtbs.elf` —
  the script matches `*dtbs.elf` for exactly this reason
- **Wi-Fi firmware is also `.elf`** (`bdwlan*.elf`, `phy_ucode*.elf`) — add `*.elf` to the script's
  patterns for the WLAN/camera blobs too
- **Run elevated** — some DriverStore subtrees are ACL'd and get skipped otherwise
- **1.1-ALT path:** no data partition — stage the firmware at `~/qcom-firmware/` in WSL *before*
  running 1.1-ALT so it's baked into the initrd; at the shell it's at `/root/qcom-firmware/`

- Final placement into `/lib/firmware/qcom/x1e80100/<VENDOR>/<MODEL>/` happens in **1.3** — the exact
  `<VENDOR>/<MODEL>` leaf is dictated by the DTB, so it's done there alongside the DTB.

### 1.3 — At the installer shell: partition → extract → chroot

> **You arrive here after 1.1 + 1.2** (or 1.1-ALT + 1.2). Flash the USB, boot it (F12), and you land
> at the Debian installer's initrd shell.
> - everything in 1.3 is identical regardless of prep — this is the actual Arch install
> - only the *rootfs source* differs: 1.1(c) → a labeled partition `LABEL=DATA` you **mount then
>   extract**; 1.1-ALT → already in the initramfs at `/root/`, **no mount**

> ⚠️ **This is an outline, not a verified transcript.** joske's gist is self-described as *"from
> memory, may be incomplete."* Take the device-specific kernel/firmware/DTB/bootloader steps from the
> gist **and** kuruczgy's config. The generic Arch-ARM steps below are safe to follow literally.

> ⚠️ **Dual-boot safety:**
> - reuse the existing Windows **ESP**, mounting it at **`/boot/efi`** (never `/boot`) — do **NOT**
>   `mkfs` it
> - never touch the Windows partitions; format **only** your new Linux root
> - one wrong `mkfs`/`fdisk` write here can destroy Windows

> 🪤 **The ESP-fills-up trap — mount the ESP at `/boot/efi`, NOT `/boot`:**
> - the Windows ESP is tiny (~100–300 MB); mount it at `/boot` and pacman writes the kernel +
>   initramfs + DTBs onto it (a fresh copy every kernel update) → it fills instantly → you're
>   hand-deleting files to make room
> - instead leave `/boot` a plain **directory on the ext4 root** (roomy), and mount the ESP at
>   `/boot/efi` where only the few-MB GRUB stub lives → **nothing to clean up**

Recommended layout (dual-boot, no wipe) — you only *add* to the disk:

| Partition | What | Recommendation |
|---|---|---|
| **ESP** | existing Windows EFI System Partition (~100–300 MB FAT) | **Reuse**, mount at **`/boot/efi`** (NOT `/boot`), never `mkfs`. Only the GRUB stub goes here. |
| **`/boot`** | a plain **directory on your ext4 root** — *not* a partition | Leave it on root. Kernel + initramfs + DTBs live here so they never touch the tiny ESP. Don't make a separate FAT `/boot`. |
| **root `/`** | your new partition in the freed space | **ext4** = simplest, boots fastest (what your 1.1a bundle formats). **Btrfs** = swarmarchy's intended scheme (Snapper rollbacks + hibernation swapfile). |
| **swap** | — | **None. Don't make a swap partition.** The swarmarchy layer sets up **zram** automatically (see below). |

Filesystem / encryption choices:

- **ext4 vs Btrfs:** start with **ext4** to prove the hardware boots (your initrd already has
  `mkfs.ext4`). Want Snapper snapshots later? Use **Btrfs** — add `btrfs-progs` to the initrd the
  same way you added `e2fsprogs` in 1.1(a); it pairs with the **Limine** bootloader. Don't gate first
  boot on it.
- **LUKS encryption:** swarmarchy's target is LUKS+Btrfs+Limine, but LUKS adds moving parts to an
  already-hard bring-up. **Skip it for the first boot;** add on a reinstall once hardware is proven.
- **No separate `/home`** for a laptop — one root keeps it simple.

> 💤 **Swap is the layer's job — so make no swap partition.** After Step 2, swarmarchy configures
> **zram** (compressed RAM swap: ½ RAM, capped 8 GB, zstd — `/etc/systemd/zram-generator.conf`),
> which the kernel uses before any disk swap. A disk swapfile is only for hibernation (auto-skips
> where unsupported — expected on Snapdragon). You don't select it during base install; the layer
> does it.

**a) Identify your disks/partitions FIRST — never guess device names.**
```sh
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,LABEL,MOUNTPOINT   # the whole picture, every disk
blkid                                                     # UUID + LABEL + TYPE per partition
fdisk -l /dev/nvme0n1 | grep -i 'EFI System'              # locate the Windows ESP (small FAT)
ls -l /dev/disk/by-label/                                 # 1.1(c): confirm your DATA partition is here
ip link                                                   # wifi iface name (wlan0 / wlp...)
```
- Pin device names to variables so destructive steps can't hit the wrong disk:
```sh
NVME=/dev/nvme0n1        # INTERNAL drive (big, ~1 TB). The USB is a separate /dev/sdX (~8 GB)!
ESP=${NVME}p1            # EXISTING Windows EFI System Partition (from the `fdisk -l` line above)
# ROOT is set below, AFTER you create the new partition.
```
  - **NVME** = internal drive; in `lsblk` the USB is the ~8 GB `/dev/sdX` — don't confuse them
  - **ESP** = the small (~100–300 MB) *EFI System* partition; it's Windows', reuse never format
  - **DATA** = your rootfs carrier at `/dev/disk/by-label/DATA` — *1.1-ALT users skip this;* the
    rootfs and firmware are in the initramfs at `/root/`

**b) Partition, extract, copy firmware, chroot in.**

  i) **Networking** — bring up Wi-Fi (gist uses a 2nd TTY: Fn+Alt+F2, return with Fn+Alt+F1).
     - from `ip link`, note your wifi iface (e.g. wlan0); make `/etc/wpa_supplicant.conf` for your
       SSID, then bring up wifi + DHCP (exact invocation per the installer environment)

  ii) **Partition** — add ONE Linux root in the free space; reuse the Windows ESP.
  ```sh
  /opt/tools/bin/fdisk.sh "$NVME"                # create ONE new root partition in the free space
  lsblk "$NVME"                                  # re-read the table -> note the NEW partition number
  ROOT=${NVME}p6                                 # <-- set to the partition you just created
  /opt/tools/bin/mkfs.ext4 "$ROOT"               # format ONLY the new root — NEVER $ESP
  ```

  iii) **Mount target + extract the rootfs into it.**
  ```sh
  mount "$ROOT" /mnt                                       # new Arch root (target)
  mkdir -p /mnt/boot/efi && mount "$ESP" /mnt/boot/efi     # ESP at /boot/efi ONLY — never /boot, never mkfs
  ```
     - `/boot` stays a dir on the ext4 root, so kernel/initrd/DTBs land on roomy ext4; the ESP only
       ever holds the GRUB stub
     - **1.1(c)** — mount the DATA carrier, then extract:
     ```sh
     mkdir -p /mnt/data && mount /dev/disk/by-label/DATA /mnt/data
     tar -xpf /mnt/data/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt
     ```
     - **1.1-ALT** — no mount; the tarball is already in the initramfs:
     ```sh
     tar -xpf /root/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt
     ```

  iv) **Copy the Qualcomm firmware → target rootfs.**
     - it loads at RUNTIME from the rootfs, so it lives in `/mnt/lib/firmware`, NOT the initrd
  ```sh
  # read the leaf the DTB wants:  dtc -I dtb -O dts <your.dtb> | grep firmware-name
  FW=/mnt/data/qcom-firmware                      # 1.1-ALT: FW=/root/qcom-firmware
  DEST=/mnt/lib/firmware/qcom/x1e80100/<VENDOR>/<MODEL>
  mkdir -p "$DEST"
  find "$FW" -type f \( -name '*.mbn' -o -name '*.jsn' -o -name '*dtbs.elf' \) \
       -exec cp {} "$DEST"/ \;                    # flatten into the leaf; match names to the DTB
  ```
     - `<VENDOR>/<MODEL>` = whatever the DTB's `firmware-name` asks for (on this laptop `LENOVO/83ED`)

  v) **Note UUIDs BEFORE chroot** (shell vars don't survive it).
  ```sh
  blkid "$ROOT" "$ESP"                           # copy these UUIDs down for /etc/fstab
  ```

  vi) **chroot in.**
  ```sh
  for d in dev proc sys run; do mount --rbind /$d /mnt/$d; done
  chroot /mnt /bin/bash
  ```

**c) Inside the chroot — base config.**

  i) **Set the clock** (or `pacman-key` fails), init keys, update.
  ```sh
  date -s "YYYY-MM-DD HH:MM:SS"
  pacman-key --init && pacman-key --populate archlinuxarm
  pacman -Syyu
  ```

  ii) **Timezone + locale.**
  ```sh
  ln -sf /usr/share/zoneinfo/<Region>/<City> /etc/localtime && hwclock --systohc
  # uncomment your locale in /etc/locale.gen, then:
  locale-gen
  echo "LANG=en_US.UTF-8" > /etc/locale.conf
  echo yoga > /etc/hostname
  ```

  iii) **Users.**
  ```sh
  passwd                                          # root password
  useradd -mG wheel <you> && passwd <you>
  EDITOR=nano visudo                              # uncomment: %wheel ALL=(ALL:ALL) ALL
  ```

  iv) **Write `/etc/fstab`** from the UUIDs you noted — TWO lines only.
  ```
  UUID=<root-uuid>  /          ext4  defaults          0 1
  UUID=<esp-uuid>   /boot/efi  vfat  defaults,noatime  0 2
  ```
     - `/boot` has NO fstab line — it's a directory on root
     - the ESP is **vfat** (not ext4), mounted at `/boot/efi`

**d) Kernel + firmware — still in the chroot.**

  i) **Install the kernel + boot tooling.**
  ```sh
  pacman -S linux-aarch64 linux-firmware mkinitcpio grub efibootmgr networkmanager sudo
  ```
     - `linux-aarch64` **populates `/boot` for you** — the kernel `Image`, `initramfs-linux.img`, and
       the `dtbs/` tree land on the ext4 `/boot` (no manual copy from the USB)

  ii) **Verify `/boot` got populated.**
  ```sh
  ls /boot                                # Image, initramfs-linux.img, dtbs/
  ls /boot/dtbs/qcom/ | grep yoga         # x1e80100-lenovo-yoga-slim7x.dtb (+ -el2 variant)
  ```

  iii) **Enable NetworkManager for the next boot** (symlink form — `systemctl enable` may balk in a
  chroot; the symlink is exactly what it does).
  ```sh
  ln -s /usr/lib/systemd/system/NetworkManager.service \
        /etc/systemd/system/multi-user.target.wants/NetworkManager.service
  ```

- **Firmware:** already copied (step b-iv) into `/mnt/lib/firmware/qcom/x1e80100/…`; after boot,
  `dmesg | grep -i firmware` names the precise path of anything still missing
- **DTB:** `qcom/x1e80100-lenovo-yoga-slim7x.dtb`
- **Graphics:** software rendering works out of the box; real acceleration = Mesa **turnip** (or the
  **zink** path until turnip is solid) — not required for first boot
- **Better kernel later:** for solid GPU/peripherals the community points to the **jhovold** branch
  (`wip/x1e80100-*`); kuruczgy's config is authoritative. Stock `linux-aarch64` is enough to boot first

> Authoritative sources: **joske's gist** (the flow) and **kuruczgy's x1e-nixos-config**
> (kernel/firmware/DTB/quirks) — both linked at the top of Step 1.

### 1.4 — Bootloader: GRUB (kept deliberately simple)

Two quirks drive the whole approach:

1. **The installer has no EFI runtime services** — `/sys/firmware/efi/efivars` is empty, so
   `efibootmgr` **can't register a boot entry from here (or the chroot).**
   - so: install GRUB to the firmware's *fallback* path now, and register a named entry **after first
     boot** (from the running system, where efivars work) — that's the "do it outside the chroot" step
2. **`grub-mkconfig` doesn't emit a `devicetree` line for aarch64**, and the Yoga won't boot without
   its DTB.
   - so: add one custom menu entry by hand

**a) In the chroot — install GRUB to the ESP's fallback path** (`EFI/BOOT/BOOTAA64.EFI`).
```sh
grub-install --target=arm64-efi --efi-directory=/boot/efi --removable --no-nvram
```
  - `--efi-directory=/boot/efi` — the ESP; the stub is a few MB, so the ESP stays roomy
  - `--removable` — writes the generic `EFI/BOOT/BOOTAA64.EFI` the firmware boots by default (no NVRAM
    entry needed to get going)
  - `--no-nvram` — skips the `efibootmgr` write that would fail in the installer

**b) Add the DTB menu entry** — grab the root UUID, then write `/etc/grub.d/40_custom` (paste the UUID in).
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

**c) Leave the chroot and reboot.**
```sh
exit
umount -R /mnt
reboot                                  # remove the USB when it powers down
```

**d) First boot** (no `efibootmgr` yet).
  - `F12` → pick the removable/USB-style entry for the internal drive (that's the fallback
    `BOOTAA64.EFI` GRUB)
  - at the GRUB menu choose **"Arch Linux ARM (Yoga Slim 7x)"** — the custom entry, *not* the
    auto-generated "Arch Linux" (which has no `devicetree`)
  - if `F12` shows nothing new, register it once from **Windows** (elevated `cmd`):
```
bcdedit /copy {bootmgr} /d "Arch"
bcdedit /set {THAT-GUID} path \EFI\BOOT\BOOTAA64.EFI
bcdedit /set {fwbootmgr} displayorder {THAT-GUID} /addfirst
```
  - PowerShell: quote every brace, e.g. `'{bootmgr}'`

**e) Once logged into Arch** — efivars now work; give yourself a clean named boot entry (the step
that **can't** run in the chroot).
```sh
sudo efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Arch Linux" -l '\EFI\BOOT\BOOTAA64.EFI'
```
  - `F12` will then list **Arch Linux** directly, alongside **Windows Boot Manager** (untouched)

> **Black screen after selecting Arch?** That's the GPU firmware, not a broken install. Press `e` in
> GRUB and add `nomodeset` to the `linux` line to reach a text console and confirm the base is good;
> fix graphics later (turnip / jhovold kernel).

Step 1 is done when you have a **plain Arch aarch64 desktop that boots and has networking.** Must be
in place:

- a recent **mainline/ALARM `linux-aarch64` (6.14+)**
- the upstream DTB **`qcom/x1e80100-lenovo-yoga-slim7x.dtb`**
- the **Qualcomm firmware** from 1.2

- To match swarmarchy's intended scheme use **LUKS + Btrfs subvolumes + Limine**, but *any* working
  Arch aarch64 base is fine — the layer doesn't care.

> Rough edges (check the guide for current status): early support had flaky touchpad, internal mics,
> and battery reporting.

## Step 2 — Apply swarmarchy (the easy part)

1. On the booted Arch ARM, logged in as your user with networking up:
```bash
git clone -b rename-swarmarchy \
  https://github.com/RAH-SOFTWARE-HOLDINGS-LTD/swarmarchy.git ~/.local/share/swarmarchy
source ~/.local/share/swarmarchy/install.sh
```
   - once you merge `rename-swarmarchy` → `master`, drop the `-b` flag (or use `boot.sh`)
2. This runs the six install phases — **packages → config → theme → login → hardware fixes → reboot**
   — and ends at a Sway desktop. It auto-handles:
   - **AUR packages:** bootstraps **yay** and pulls walker/bluetui/impala/etc. (`displaylink`/`evdi`
     stay opt-in — add only if you use the adapter)
   - **Login screen:** sets up **greetd + tuigreet** to launch Sway at boot
3. Reboot → log in → you're in Sway.

## Step 3 — Verify on bare metal & fix quirks

- The VM only proved the *software config*. These need **real hardware** (keys/devices) — run them
  once you're in Sway on the Yoga and tick them off:

- [ ] Media keys: volume up/down/mute, mic-mute (`XF86Audio*`) → SwayOSD popup shows
- [ ] Brightness keys (`XF86MonBrightness*`) → backlight changes + OSD
- [ ] `Print` → screenshot · `Super+Ctrl+Print` → OCR text-grab
- [ ] Lid close/open → display off/on · `Super+Ctrl+Delete` → laptop-display toggle
- [ ] `Super+/` → monitor scaling · `Super+Ctrl+N` → nightlight (wlsunset)
- [ ] GPU acceleration (Mesa **turnip** — `vulkaninfo`, or any GL/Vulkan app)
- [ ] Wi-Fi · Bluetooth (Bose headphones) · audio in/out
- [ ] DisplayLink adapter · fingerprint · ZMK keyboard · Razer mouse

- Expect a few to need tweaks — normal on new hardware. The x86-only hardware-fix scripts
  (Intel/Nvidia/Apple/Asus/Framework) auto-skip on Snapdragon — harmless.

### Fixing something that's broken (the loop)

- Your install at `~/.local/share/swarmarchy` is a **git clone**, so iteration is fast — no reinstall:

1. Edit the offending `swarmarchy-*` script (plain shell — on the machine or your dev box)
2. `git commit` + `git push`
3. Pull it back where needed: `git -C ~/.local/share/swarmarchy pull` (or `swarmarchy-update`)

---

## Troubleshooting

### Flashed USB doesn't show up in Windows Explorer (no drive letter)

- After Rufus DD-clones the Codelinaro image, the boot partition often **won't appear in Explorer** and
  has **no drive letter**. Expected — not a failed flash:
  - the image tags its partition MBR type byte **`0x83` (Linux)** though the filesystem is **FAT**;
    Windows auto-letters only its own types (`0x06`/`0x0b`/`0x0c`/`0x07`…), so it skips `0x83`
  - `Get-Volume` still lists it as a `FAT` volume, just with a blank `DriveLetter`
  - Disk Management's *Change Drive Letter and Paths…* is greyed out (Windows treats `0x83` as
    foreign); the CLI tools below override that

**a) Assign a letter from an *admin* PowerShell.**
```powershell
Get-Disk                                              # find the Kingston/USB disk number, e.g. 2
Get-Partition -DiskNumber 2                           # confirm the FAT partition number (usually 1)
Set-Partition -DiskNumber 2 -PartitionNumber 1 -NewDriveLetter E
```
  - or the same in `diskpart` (admin):
```
diskpart
select disk 2
select partition 1
assign letter=E
exit
```
  - `E:` then shows in Explorer. Non-destructive, stays bootable. (`Set-Partition` without admin →
    `Access denied`.)

**b) Stick not visible to Windows at all** (not even Disk Management) — check it isn't attached to WSL
via **usbipd**, which removes it from Windows entirely.
```bash
"/mnt/c/Program Files/usbipd-win/usbipd.exe" list                  # STATE = Attached?
"/mnt/c/Program Files/usbipd-win/usbipd.exe" detach --busid <BUSID>
```

**c) Auto-mount on every future plug-in (optional)** — flip the type byte to FAT so Windows automount
handles it unconditionally.
  - `diskpart → select disk/partition → set id=0c`, or from WSL `sudo sfdisk --part-type /dev/sdX 1 c`
  - afterward it letters itself like a normal stick; revert with `set id=83` / `sfdisk … 1 83` if the
    Qualcomm boot flow objects to the changed type

> **Why it "used to just work":** Windows keys a volume→letter map in `HKLM\SYSTEM\MountedDevices` to
> the disk's 4-byte **MBR signature**. A raw DD flash writes the image's own signature, and `diskpart
> clean` erases the signature outright — both orphan the old mapping, so the letter must be
> reassigned. (`clean` also wipes the whole partition table — grow into free space with `extend` or
> GParted instead.)

## References

- joske gist · kuruczgy NixOS config · Ubuntu Concept ISO
- daily-driver writeup: https://varunpriolkar.com/2025/07/daily-driving-an-arm-linux-laptop/
- remaining ISO-build blockers: `swarmarchy-iso/BUILD-AARCH64.md`
