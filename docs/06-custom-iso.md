# Path B — Build the custom swarmarchy USB installer (aarch64)

The polished, one-shot installer (the Omarchy-ISO experience). This is the **ambitious,
less-certain** path and is **not required to run swarmarchy** — Path A (`05`) gets it onto
the Yoga without any of this. Treat this as a later polish goal.

The build mechanics + live blocker tracking live in **`swarmarchy-iso/BUILD-AARCH64.md`**;
this doc is the *strategy* and how the pieces fit.

> **Path A is now done.** For the concrete, decided build plan — locked choices, ordered
> steps, open questions — see **[`07-iso-build-plan.md`](./07-iso-build-plan.md)**.
> Two things below are stale as a result:
> - The kernel/DTB worry is settled — stock ALARM `linux-aarch64` ships the Yoga DTB.
> - **All ISO work is on `master`** now; it used to live on `rename-swarmarchy`, and `master`
>   used to be untouched upstream `omarchy-iso`. Both are the same commit today.

---

## Where this fits — Path A is a prerequisite, not just "easier"

You **cannot** build a correct auto-installer until Path A has told you *which kernel +
firmware + DTB actually boot the Yoga*. Path A answers that (and proves the layer runs on
real ARM hardware); Path B then just bundles that known-good set into a USB. So Path B work
does not begin until Path A is on your machine and validated.

```
[Path A — docs/05]                          [Path B — starts after A is done]
 0  Windows prep                             B1  feed the known-good kernel +
 1  joske → bare Arch ARM boots  ← hard part     firmware + DTB into swarmarchy-iso
 2  run swarmarchy layer → Sway              B2  fix the ISO builder for aarch64
 3  verify HW; note the exact   ───────────▶     (archiso `releng` is x86-only →
    kernel/firmware/DTB that worked               likely switch to `archboot`)
                                             B3  build → test in VM → write USB → done
```

**Do Path A first.** Everything below is parked until then.

## The core problem
`mkarchiso` / archiso's `releng` profile is **x86_64-only** — there is no upstream
aarch64 profile, so you can't just point the existing build at aarch64. Two routes:

1. **Switch to `archboot`** *(likely lower-friction)* — it genuinely builds aarch64 ISOs.
   You'd rework `builder/build-iso.sh` around archboot instead of mkarchiso.
2. **Adapt the `releng` profile for aarch64** — grub-aarch64 / systemd-boot bootloader,
   aarch64 package list, EFI boot images. More from-scratch.

## What the ISO must carry to boot the Yoga
- The **Snapdragon kernel** (mainline/ALARM `linux-aarch64` 6.14+) + the upstream
  **`qcom/x1e80100-lenovo-yoga-slim7x.dtb`**.
- **Qualcomm firmware** — licensing blocks redistribution, so either extract-from-Windows
  at install time, or make it a documented user step.
- A working **grub-aarch64 UEFI** boot path (Secure Boot off on the device).

## Already done in `swarmarchy-iso` (the easy 80%)
- `configs/profiledef.sh`: `arch=aarch64`, `bootmodes=('uefi.grub')`, x86 BCJ filter dropped ✓
- `builder/build-iso.sh`: `ARCH` var, `packages.$ARCH`, Node `linux-arm64`, strips x86-only ✓
- `configs/pacman-online-*.conf`: **generic Arch Linux ARM mirror** (no omarchy repo) ✓
- Keyring: verifies with `archlinuxarm-keyring` ✓
- `.github/workflows/build-iso.yml`: native `ubuntu-24.04-arm` runner ✓
- **NOT yet:** a single successful end-to-end build (blocked on the releng-aarch64
  problem above + bundling the kernel/firmware/DTB).

## The build → test loop
1. Run `./bin/swarmarchy-iso-make` (or trigger the GitHub Action) → see exactly where it
   breaks. Expect it to fail around mkarchiso/releng-aarch64.
2. Fix — most likely **switch `build-iso.sh` to archboot**, then re-run.
3. Once an ISO is produced, boot it in the **aarch64 VM** (`04-testing.md` Step 1) to test
   the installer flow, then on the real Yoga.
4. Write to USB: `sudo dd if=release/swarmarchy.iso of=/dev/sdX bs=4M status=progress`
   (or Rufus / Balena Etcher on Windows).

## Remaining blockers (tracked in `swarmarchy-iso/BUILD-AARCH64.md`)
- **#3** archiso has no aarch64 profile → archboot, or adapt releng (the big one).
- **#4** Snapdragon kernel + firmware + DTB must be bundled into the ISO.
- AUR packages (`walker`, `yay`, `displaylink`/`evdi`): baked into the offline mirror vs.
  built on first boot.

## How this relates to Path A
Path A proves the *layer* works on real hardware and surfaces the kernel/firmware set you
need. That knowledge feeds directly into Path B — once you know exactly which kernel +
firmware + DTB boot the Yoga (from doing Path A), bundling them into the custom ISO is the
main remaining work. **Do Path A first; it de-risks Path B.**

---

## Flashing the USB

Run these on a working Linux box (your current Arch install) — not on the Yoga's installer.

**Nothing to install.** `dd`, `lsblk` and `sync` come with `coreutils`/`util-linux`. The ISO is
hybrid-bootable (`DOS/MBR boot sector`), so a raw `dd` is all it needs — no `isohybrid`, no Ventoy,
no Etcher.

1. **Plug the USB in, then find its device name**

   ```sh
   lsblk -o NAME,SIZE,TRAN,RM,MODEL,MOUNTPOINT
   ```

   - Take the row with `TRAN=usb` and `RM=1` — usually `/dev/sda`.
   - `nvme0n1` is the internal disk. Writing there destroys Windows *and* Linux.
   - Needs a 4 GB stick or larger.

2. **Point a variable at it, editing `sda` to match step 1**

   ```sh
   USB=/dev/sda
   ```

3. **Select the newest ISO**

   ```sh
   ISO=$(ls -t ~/.local/share/swarmarchy-iso/release/*.iso | head -1); echo "$ISO"
   ```

   - It echoes what it picked — check the date is the build you meant. Old ISOs stay in that
     directory and are easy to grab by mistake.

4. **Unmount anything the desktop auto-mounted from the stick**

   ```sh
   sudo umount ${USB}?* 2>/dev/null || true
   ```

   - Unmount the *partitions*; the write targets the whole device.

5. **Write it**

   ```sh
   sudo dd if="$ISO" of="$USB" bs=4M conv=fsync oflag=direct status=progress
   ```

   - Takes a few minutes for 3.1 GB. `dd` does not ask for confirmation and does not warn.
   - Target the whole device (`/dev/sda`), never a partition (`/dev/sda1`).

6. **Flush and confirm**

   ```sh
   sync
   lsblk -f "$USB"
   ```

   - Expect a partition labelled `SWARMARCHY_<date>`. If the label is missing, the write did not
     land — do not boot it.

Then continue with §"Running the installer" below.


---

## Running the installer (boot → shrink → install)

The dual-boot install, start to finish, on the Yoga. Assumes a USB already flashed with
`swarmarchy-<date>-aarch64-master.iso`.

**Before you start:** the installer never shrinks anything by itself — steps 4-9 free the space,
step 10 installs into it. Windows and any existing Linux are only read, never written.

1. **Boot the USB**

   Power on and tap `F12` for the Lenovo boot menu, then pick the USB entry.

   - Secure Boot must be off (`05` Step 0).
   - No USB entry? Re-seat the stick and retry — the firmware only rescans on a cold boot.

2. **Get a shell instead of the installer**

   Press `Ctrl+Alt+F2`.

   - The installer auto-runs on **tty1 only** (`.zlogin` → `.automated_script.sh`, gated on
     `$(tty) == /dev/tty1`). Any other tty is a plain root shell.
   - Do not do the resize on tty1 — the installer is already running there.

3. **Confirm which partition is the Linux root**

   ```sh
   lsblk -f
   ```

   - Expect `nvme0n1p1` = ESP (vfat, `SYSTEM`), `nvme0n1p2` = Windows (ntfs), `nvme0n1p3` = root (ext4).
   - **Check this every time.** Partition numbers shift when partitions are added or deleted.
   - Nothing on `nvme0n1` is mounted right now — you booted from USB. That is what makes the
     resize safe.

4. **Check the filesystem before touching it**

   ```sh
   sudo e2fsck -f /dev/nvme0n1p3
   ```

   - `resize2fs` refuses to shrink a filesystem that has not been checked.
   - Fix anything it reports before going further.

5. **Shrink the filesystem**

   Pick the new root size in **GiB** and shrink to it:

   ```sh
   sudo resize2fs /dev/nvme0n1p3 150G
   ```

   - `resize2fs`'s `G` means **GiB** (1024 MiB), not GB. `150G` = 153600 MiB.
   - **Filesystem first, partition second.** A partition smaller than its filesystem destroys data.
   - Free at least **21 GiB** or the installer will not offer the alongside option. Leaving
     80-120 GiB free is comfortable.

6. **Work out the new partition end — do not hand-calculate it**

   Read the real filesystem size and the real partition start, then derive the end:

   ```sh
   FS_MIB=$(sudo dumpe2fs -h /dev/nvme0n1p3 2>/dev/null | awk '/^Block count:/{c=$3} /^Block size:/{b=$3} END{printf "%d", (c*b)/1048576}')
   START_MIB=$(sudo parted -ms /dev/nvme0n1 unit MiB print | awk -F: '$1=="3"{gsub(/MiB/,"",$2); printf "%d", $2}')
   END_MIB=$(( START_MIB + FS_MIB + 256 ))
   echo "fs=${FS_MIB}MiB  start=${START_MIB}MiB  new end=${END_MIB}MiB  size=$(( END_MIB - START_MIB ))MiB"
   ```

   - `FS_MIB` comes from the filesystem itself, so it is correct whatever size was used in step 5.
   - `parted` takes an **end offset**, not a size — hence `start + size`.
   - The 256 MiB margin guarantees the partition is never smaller than the filesystem. Step 8
     reclaims it.

7. **Confirm it is safe, then shrink the partition**

   This refuses to print the `parted` line unless the partition will still contain the filesystem:

   ```sh
   if [ $(( END_MIB - START_MIB )) -ge "$FS_MIB" ]; then
     sudo parted /dev/nvme0n1 unit MiB resizepart 3 "$END_MIB"
   else
     echo "ABORT: partition would be smaller than the filesystem — do not continue"
   fi
   ```

   - If it prints ABORT, stop. Re-run step 5 with a smaller size and redo step 6.
   - `parted` 3.x only moves the boundary; it never touches the filesystem.

8. **Grow the filesystem back to fill the partition**

   ```sh
   sudo resize2fs /dev/nvme0n1p3
   sudo e2fsck -f /dev/nvme0n1p3
   sudo parted /dev/nvme0n1 unit GiB print free
   ```

   - With no size argument `resize2fs` expands to exactly the partition, removing the margin.
   - The free-space line at the end is what the installer will offer to use.
   - Shrinking preserves the partition UUID and slot number, so the existing GRUB entry still boots.

9. **Stage the Qualcomm firmware (optional, Yoga only)**

   Plug in the stick holding the `firmware/` directory from `copy-qcom-firmware.ps1`.

   - The installer scans attached filesystems for it and places the blobs at the board path.
   - Skip it and the install still finishes — you just get no DP-alt monitors, no audio and
     software rendering until the blobs are added by hand (`05` §"External monitors").

10. **Run the installer**

    ```sh
    ~/.automated_script.sh
    ```

    - Or switch back with `Ctrl+Alt+F1` if you have not started it there yet.
    - Choose **"Install alongside"** when asked. The wipe option destroys Windows.
    - It creates a 1 GiB ESP plus a Btrfs root in the free space, installs Limine to its own ESP,
      and appends its firmware boot entry rather than taking over the boot order.

