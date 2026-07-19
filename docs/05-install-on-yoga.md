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
4. **Collect the Qualcomm firmware** — elevated PowerShell:
   ```powershell
   .\copy-qcom-firmware.ps1 -Destination C:\qcom-firmware\
   ```
   - needed by Linux, lives only in Windows
   - grabs `*.mbn` `*.jsn` `*dtbs.elf` from `…\DriverStore\FileRepository\` + a `MANIFEST.csv`
   - add `*.elf` to also get Wi-Fi/camera blobs
   - run elevated or ACL'd dirs get skipped
   - reachable from WSL later at `/mnt/c/qcom-firmware`

## Step 1 — Get bare Arch Linux ARM booting ⚠️

### 1.1 — Prep the installer USB (one self-contained image)

- bakes the rootfs **and** firmware into one enlarged initrd on the image's single FAT boot partition
  - at the installer shell everything's already in RAM at `/root/` — nothing to mount
  - ~935 MB initrd → the boot partition grows ~300 MB → ~1.5 GB (loads to RAM; needs ≥ 4 GB free)
- 🧪 built + verified in WSL; boot on the Yoga still unverified
- do all of 1.1 in **WSL (Debian arm64)**

> ⚠️ **No loop devices in WSL.**
> - WSL2 lacks `HDIO_GETGEO` on `/dev/loopNpX` → `mount`/`fatresize`/`mformat` fail
> - work on the image **file**: `sfdisk`, `mkfs.vfat` on a scratch file, `mtools @@offset`, `dd`
> - image is **MBR** — use `sfdisk`/`fdisk`, not `sgdisk`

**a) Build a self-contained `fdisk` + `mkfs.ext4` bundle**
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

**b) Set up WSL + inputs** (tools, rootfs tarball, Step 0 firmware, and point `SRC` at the image)
```bash
cd ~
sudo apt-get install -y util-linux mtools dosfstools cpio gzip
wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
cp -r /mnt/c/qcom-firmware ~/qcom-firmware
SRC=/mnt/c/Users/<you>/Downloads/<codelinaro>.img       # the DOWNLOADED image, left untouched
```

**c) Bake the fat initrd** (original initrd + tools + rootfs)
  - `sudo` preserves the original's `/dev` nodes
  - no `~/initrd.orig.gz`? pull it from SRC: `MTOOLS_SKIP_CHECK=1 mcopy -i "$SRC"@@$((2048*512)) ::/initrd.gz ~/initrd.orig.gz`
```bash
rm -rf ~/initrd-baked && mkdir ~/initrd-baked && cd ~/initrd-baked
sudo sh -c 'zcat ~/initrd.orig.gz | cpio -idmv'
sudo cp -a ~/initrd-tools/opt .                         # -> /opt/tools/
sudo cp ~/ArchLinuxARM-aarch64-latest.tar.gz root/      # -> /root/
sudo sh -c 'find . | cpio -o -H newc | gzip > ~/initrd.baked.gz'    # ~905 MB
```

**d) Append the firmware as a second cpio segment**
  - the kernel concatenates initramfs archives
```bash
rm -rf ~/fwseg && mkdir -p ~/fwseg/root && cp -a ~/qcom-firmware ~/fwseg/root/
( cd ~/fwseg && find root | cpio -o -H newc 2>/dev/null | gzip ) > ~/fw.cpio.gz
cat ~/initrd.baked.gz ~/fw.cpio.gz > ~/initrd.final.gz   # ~935 MB
zcat ~/initrd.final.gz | grep -a -c 'qcom-firmware/MANIFEST.csv'    # expect 1
```

**e) Extract SRC's boot tree, swap in the fat initrd**
  - `mtools @@offset` reads the FAT (sector 2048) straight out of the file
```bash
O=$((2048*512))
rm -rf ~/p1extract && mkdir ~/p1extract
MTOOLS_SKIP_CHECK=1 mcopy -s -i "$SRC"@@$O "::/*" ~/p1extract/
cp ~/initrd.final.gz ~/p1extract/initrd.gz
```

**f) Rebuild that partition as a larger FAT, copy the tree back**
```bash
rm -f ~/p1.img; truncate -s 1500M ~/p1.img
mkfs.vfat -F32 -n BOOT ~/p1.img
( cd ~/p1extract && MTOOLS_SKIP_CHECK=1 mcopy -s -i ~/p1.img boot boot.cat dtb EFI gtk initrd.gz linux :: )
```

**g) Assemble the whole-disk image** (one MBR partition, type 83 bootable, at sector 2048)
```bash
rm -f ~/usb-single.img
SECT=$(( $(stat -c%s ~/p1.img) / 512 ))
truncate -s $(( (2048 + SECT) * 512 )) ~/usb-single.img
printf 'label: dos\nunit: sectors\nstart=2048, size=%s, type=83, bootable\n' "$SECT" | sfdisk ~/usb-single.img
dd if=~/p1.img of=~/usb-single.img bs=512 seek=2048 conv=notrunc status=progress
```

**h) Verify + copy out to flash**
```bash
MTOOLS_SKIP_CHECK=1 mdir -i ~/usb-single.img@@$O ::      # linux + initrd.gz present
cp ~/usb-single.img /mnt/c/Users/<you>/Downloads/usb-single.img
```

- Rufus DD-flash `usb-single.img` (accept DD/MBR)
- at the installer shell the rootfs + firmware are already at `/root/` → continue to 1.3

> Gotchas:
> - `cpio -t` lists only the first segment — verify with `zcat … | grep -a`
> - FAT must fit the fat initrd (1500 MB ⇒ ~450 MB slack)
> - never `truncate` SRC (read-only)
> - `mkfs.vfat` missing → install `dosfstools`

### 1.2 — Stage the firmware for the installer

- **1.1 (baked)** — the firmware is already inside the initrd (step d); at the shell it's `/root/qcom-firmware/`
- **Alternate (DATA)** — copy the Step 0 firmware onto the DATA partition
  - `cp -r /mnt/c/qcom-firmware /mnt/data/`
- either way, 1.3 places it onto the NVMe

### 1.3 — At the installer shell: partition → extract → chroot

> After 1.1. Flash, boot (F12), land at the initrd shell.
> - baked method (1.1): rootfs + firmware already in RAM at `/root/`
> - alternate (DATA): mount `LABEL=DATA` first

> ⚠️ **Outline, not a verified transcript** — take device-specific kernel/DTB bits from the gist + kuruczgy.

> 🪤 **Dual-boot / ESP — mount at `/boot/efi`, never `/boot`:**
> - the ESP is tiny; at `/boot` pacman fills it with kernels
> - keep `/boot` on the ext4 root; only the GRUB stub lands on the ESP
> - never `mkfs` the ESP; format only your new root — one wrong write kills Windows

Layout (add-only):

| Partition | Recommendation |
|---|---|
| **ESP** (existing Windows EFI) | reuse, mount at **`/boot/efi`**, never `mkfs` |
| **`/boot`** | directory on the ext4 root, not a partition |
| **root `/`** | **ext4** (simplest) or Btrfs (swarmarchy's scheme; needs `btrfs-progs` in initrd + Limine) |
| **swap** | none — the layer sets up zram |

- LUKS: swarmarchy targets LUKS+Btrfs+Limine
  - skip it for the first boot; add on reinstall

**a) Identify disks — never guess:**
```sh
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,LABEL,MOUNTPOINT
blkid
fdisk -l /dev/nvme0n1 | grep -i 'EFI System'    # the Windows ESP
ip link                                          # wifi iface

NVME=/dev/nvme0n1        # internal drive; USB is a separate /dev/sdX
ESP=${NVME}p1            # existing Windows ESP — reuse, never format
```
  - alternate (DATA) users: also note your DATA partition at `/dev/disk/by-label/DATA`

**b) Partition → extract → firmware → chroot:**

i) **Wi-Fi:**
   - from `ip link`, make `/etc/wpa_supplicant.conf`, bring up wifi + DHCP
   - 2nd TTY: Fn+Alt+F2

ii) **Partition + format the new root:**
```sh
/opt/tools/bin/fdisk.sh "$NVME"     # create ONE new root partition in the free space
lsblk "$NVME"                       # note the NEW partition number
ROOT=${NVME}p6                      # <-- set to the partition you just created
/opt/tools/bin/mkfs.ext4 "$ROOT"    # format ONLY the new root — NEVER $ESP
```

iii) **Mount + extract:**
```sh
mount "$ROOT" /mnt
mkdir -p /mnt/boot/efi && mount "$ESP" /mnt/boot/efi     # ESP at /boot/efi ONLY
tar -xpf /root/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt      # baked method
# Alternate (DATA):
#   mkdir -p /mnt/data && mount /dev/disk/by-label/DATA /mnt/data
#   tar -xpf /mnt/data/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt
```

iv) **Copy firmware onto the root:**
   - leaf comes from the DTB's `firmware-name` (e.g. `LENOVO/83ED`)
```sh
FW=/root/qcom-firmware                                  # Alternate (DATA): FW=/mnt/data/qcom-firmware
DEST=/mnt/lib/firmware/qcom/x1e80100/<VENDOR>/<MODEL>
mkdir -p "$DEST"
find "$FW" -type f \( -name '*.mbn' -o -name '*.jsn' -o -name '*dtbs.elf' \) -exec cp {} "$DEST"/ \;
```

v) **Note UUIDs, then chroot:**
   - vars don't survive the chroot
```sh
blkid "$ROOT" "$ESP"
for d in dev proc sys run; do mount --rbind /$d /mnt/$d; done
chroot /mnt /bin/bash
```

**c) Base config (in chroot):**
```sh
date -s "YYYY-MM-DD HH:MM:SS"                            # or pacman-key fails
pacman-key --init && pacman-key --populate archlinuxarm
pacman -Syyu
ln -sf /usr/share/zoneinfo/<Region>/<City> /etc/localtime && hwclock --systohc
# uncomment your locale in /etc/locale.gen, then:
locale-gen && echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo yoga > /etc/hostname
passwd
useradd -mG wheel <you> && passwd <you>
EDITOR=nano visudo                                      # uncomment %wheel
```
`/etc/fstab` — two lines only:
  - `/boot` has none; ESP is **vfat**
```
UUID=<root-uuid>  /          ext4  defaults          0 1
UUID=<esp-uuid>   /boot/efi  vfat  defaults,noatime  0 2
```

**d) Kernel (in chroot):**
```sh
pacman -S linux-aarch64 linux-firmware mkinitcpio grub efibootmgr networkmanager sudo
ls /boot && ls /boot/dtbs/qcom/ | grep yoga             # kernel Image + Yoga DTB on ext4 /boot
ln -s /usr/lib/systemd/system/NetworkManager.service \
      /etc/systemd/system/multi-user.target.wants/       # wifi next boot
```
  - firmware already at `/mnt/lib/firmware/...`
    - after boot `dmesg | grep -i firmware` names anything missing
  - GPU accel = Mesa turnip later; stock `linux-aarch64` boots fine now

### 1.4 — GRUB

Two quirks:

1. the installer has no efivars → `efibootmgr` can't run here
   - install to the fallback path, register after boot
2. `grub-mkconfig` omits the aarch64 `devicetree` line
   - add a custom entry

**a) Install GRUB to the ESP fallback path (in chroot):**
```sh
grub-install --target=arm64-efi --efi-directory=/boot/efi --removable --no-nvram
```

**b) Custom entry with the DTB:**
   - paste the root UUID (`blkid -s UUID -o value "$ROOT"`) into `<ROOT-UUID>`
```sh
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
grep -i devicetree /boot/grub/grub.cfg                  # must print the devicetree line
```

**c) Exit + reboot:**
   - `exit` → `umount -R /mnt` → `reboot` (remove USB)

**d) First boot:**
   - F12 → the removable/internal-drive entry → GRUB → pick **"Arch Linux ARM (Yoga Slim 7x)"**
     - not the auto "Arch Linux", which lacks the DTB
   - F12 shows nothing? register from Windows (elevated `cmd`):
```
bcdedit /copy {bootmgr} /d "Arch"
bcdedit /set {GUID} path \EFI\BOOT\BOOTAA64.EFI
bcdedit /set {fwbootmgr} displayorder {GUID} /addfirst
```

**e) After login** (efivars work now) — clean named entry:
```sh
sudo efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Arch Linux" -l '\EFI\BOOT\BOOTAA64.EFI'
```

> Black screen after picking Arch? GPU firmware, not a broken install — add `nomodeset` (press `e`) to
> reach a console.

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

## Step 3 — Verify on hardware

- [ ] Media/brightness keys → SwayOSD · `Print` screenshot · lid open/close
- [ ] `Super+/` scaling · `Super+Ctrl+N` nightlight
- [ ] GPU accel (turnip — `vulkaninfo`) · Wi-Fi · Bluetooth · audio
- [ ] DisplayLink · fingerprint · ZMK keyboard · Razer mouse

- x86-only hardware-fix scripts auto-skip on Snapdragon
- fix loop: edit the `swarmarchy-*` script → commit/push → `swarmarchy-update`

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

**a) Build the `fdisk` + `mkfs.ext4` bundle** — same as **1.1(a)** (produces `~/initrd-tools/opt`).

**b) Inject the tools into the initrd, repack**
  - as root, to keep `/dev` nodes
  - point `../initrd.gz` at the Codelinaro initrd
```bash
mkdir -p ~/initrd-tools/initrd-work && cd ~/initrd-tools/initrd-work
sudo sh -c 'zcat ../initrd.gz | cpio -idmv'         # unpack the ORIGINAL (confirm gzip: file ../initrd.gz)
sudo cp -a ~/initrd-tools/opt .                     # inject /opt/tools ONLY (no rootfs!)
sudo sh -c 'find . | cpio -o -H newc | gzip > ../initrd-new.gz'  # repack (~130-140 MB)
```
  - zstd/xz/lz4 original → swap `zcat`/`gzip` accordingly

**c) Create the DATA partition + copy the rootfs**
  - after Rufus DD-flashes (accept DD/MBR), make a second **FAT32** partition in the free space, label `DATA`
  - FAT32 not NTFS — the minimal initrd has no NTFS driver
```bash
cd ~ && wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
sudo mkdir -p /mnt/data
sudo mount -t drvfs F: /mnt/data                    # F: = the DATA partition's letter
cp ~/ArchLinuxARM-aarch64-latest.tar.gz /mnt/data/  # copy AS-IS, don't unpack
```
  - no drive letter? Disk Management → *Change Drive Letter and Paths* → *Add* (greyed out → Troubleshooting)

**d) Copy the Step 0 firmware onto DATA**
```bash
cp -r /mnt/c/qcom-firmware /mnt/data/
```

- overwrite the boot partition's `initrd.gz` with `initrd-new.gz`, then continue at **1.3**
  - at the installer shell you mount `LABEL=DATA` (see the alternate lines in 1.3 b-iii/iv)

## References

- joske gist · kuruczgy NixOS config
- [daily-driver writeup](https://varunpriolkar.com/2025/07/daily-driving-an-arm-linux-laptop/)
- ISO blockers in `swarmarchy-iso/BUILD-AARCH64.md`
