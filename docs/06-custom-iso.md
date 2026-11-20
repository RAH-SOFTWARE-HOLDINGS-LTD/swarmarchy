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

   - Takes a few minutes. `dd` does not ask for confirmation and does not warn.
   - Target the whole device (`/dev/sda`), never a partition (`/dev/sda1`).

6. **Flush, then verify the whole image byte for byte**

   ```sh
   sync
   sudo cmp -n $(stat -c%s "$ISO") "$ISO" "$USB"
   ```

   - **Silence means identical.** Any output means re-flash; do not boot it.
   - Takes a few minutes. Do it anyway — see below for why nothing cheaper works.
   - `dd` must be allowed to finish. It prints a `records in / records out / bytes copied`
     summary when it is genuinely done; interrupting it leaves a stick that still looks bootable.

   A partial rewrite over an older ISO passes every cheap check, because the head of the image is
   written first and correctly:

   - The **label** is only year and month (`SWARMARCHY_202609`) — identical across builds.
   - The **UUID** lives in the volume descriptor at 32 KiB, so it reads as the new build even when
     the write stopped a gigabyte later. `blkid`/`lsblk` also cache it, and the cache survives a
     rewrite, so a correct stick can report the *previous* build's UUID. `blkid -p` bypasses the
     cache but still only proves the first 32 KiB landed.
   - The result is a stick holding the head of one ISO and the tail of another. It boots, then
     fails strangely once it reads the corrupted squashfs.

Then continue with §"Running the installer" below.


---

## Supported boards (Snapdragon X1 / X2)

The ISO is no longer Yoga-only. Every Snapdragon X laptop the stock ALARM `linux-aarch64` ships a
device tree for can boot it. That is 32 DTBs as of 7.3.3: `x1e*`, `x1p*`, `hamoa`, `purwa`,
`glymur`, `mahua`, with the `-el2` variants left out. **Only the Yoga Slim 7x has been booted.**
Every other board is untested.

How the pieces fit:

| Step | Where | What it does |
|---|---|---|
| Pick the DTB | `configs/grub/grub.cfg` + generated `boards-match.cfg` | GRUB reads SMBIOS Manufacturer/Product Name. A row in `configs/boards.tsv` boots its DTB straight away. No match: a menu of every DTB. |
| Remember it | `swarmarchy.devicetree=` on the live cmdline | `swarmarchy-hw-snapdragon dtb` returns it to the installer. |
| Boot args + DTB | `.automated_script.sh`, `install/login/limine-snapper.sh` | Both call `swarmarchy-hw-snapdragon cmdline` / `dtb`. Nothing names a board. |
| Firmware | `swarmarchy-stage-qcom-firmware` | Places every file the DT's `firmware-name` properties request, from the private bundle or a `copy-qcom-firmware.ps1` stick. |

**Adding or fixing a board:**
- **Regenerate the table** from a dtbloader checkout:
  `builder/import-dtbloader-boards.py <dtbloader> <commit> > configs/boards.tsv`.
  - dtbloader is <https://github.com/TravMurav/dtbloader>, BSD-3.
  - It joins dtbloader's per-machine `fwupdtool hwids` dumps to its DTB list.
  - Lenovo matches on the 4-character machine type (`^83ED`); other vendors match exactly.
- **Add a hand-made row** below the `# --- local rows below ---` marker. Columns:
  `vendor`, `product_re`, `dtb`, `name`, `auto`, `verified`, `source`.
- **Rows whose DTB the kernel does not ship are skipped** with a build warning. As of dtbloader
  `b1bf23e`, 9 of 31 are skipped, mostly name mismatches such as `sp12` vs `sp12in`. Those
  machines still boot from the menu.
- **Mark a row `verified=yes`** once someone has booted the ISO on it.

**Bundled firmware (private ISO):** `~/swarmarchy-pkgs-build/local/firmware` is laid out by DT
firmware dir, e.g. `x1e80100/LENOVO/83ED/qcadsp8380.mbn`, so one ISO can carry several boards and
each only ever gets its own blobs. Loose files at the top are ignored, with a log line saying so.
Run `swarmarchy-hw-snapdragon firmware` on a board to see the exact dir it wants.

## Running the installer (boot → shrink → install)

The dual-boot install, start to finish, on the Yoga. Assumes a USB already flashed with
`swarmarchy-<date>-aarch64-master.iso`.

**Before you start:** the installer never shrinks anything by itself. Steps 6-9 free space for a
first install; step 4 lets you skip them when reinstalling over an existing Swarmarchy. Windows and
any existing Linux are only read, never written.

1. **Boot the USB**

   Power on and tap `F12` for the Lenovo boot menu, then pick the USB entry.

   - Secure Boot must be off (`05` Step 0).
   - No USB entry? Re-seat the stick and retry — the firmware only rescans on a cold boot.
   - A laptop in `configs/boards.tsv` boots straight to the installer, as before. Any other laptop
     stops at a GRUB menu: pick **"Swarmarchy on <your laptop>"**. The DTB name is in brackets.

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

4. **Already have a Swarmarchy install? Skip to step 10**

   The installer detects a previous install by its partition labels (`SWARMBOOT` + `swarmarchy`)
   and offers to reinstall onto it, reformatting only those two. Steps 6-9 are for making room the
   *first* time.

   ```sh
   lsblk -o NAME,SIZE,FSTYPE,LABEL /dev/nvme0n1
   ```

   - Both labels present → no resizing, no deleting. Go to step 10.
   - Neither present → carry on with step 6 to free space.
   - The confirmation screen lists what gets reformatted and what is left alone, so you can see
     Swarmarchy is being replaced and the other OS is not.

5. **Check the filesystem**

   ```sh
   e2fsck -f /dev/nvme0n1p3
   ```

   - `resize2fs` refuses to shrink a filesystem that has not been checked.

6. **Shrink the filesystem** — pick the new root size in GiB

   ```sh
   resize2fs /dev/nvme0n1p3 140G
   ```

   - Leave at least **21 GiB** free or the installer will not offer the alongside option.
     80-120 GiB free is comfortable.
   - **Filesystem first, partition second.** A partition smaller than its filesystem destroys data.

7. **Shrink the partition to that number + 1**

   ```sh
   echo ',141G' | sfdisk -N 3 --force /dev/nvme0n1
   ```

   - The only arithmetic is **+1**. `G` means GiB in both commands, so the numbers line up.
   - The spare GiB guarantees the partition cannot end up smaller than the filesystem. Step 8
     reclaims it.
   - The leading `,` means "leave the start where it is" — you never type an offset, and `sfdisk`
     takes a size rather than an end position.

8. **Grow the filesystem back and check**

   ```sh
   resize2fs /dev/nvme0n1p3
   e2fsck -f /dev/nvme0n1p3
   parted /dev/nvme0n1 unit GiB print free
   ```

   - Bare `resize2fs` expands to exactly the partition, removing the spare GiB.
   - The free-space line is what the installer will offer to use.
   - The partition keeps its UUID and number, so the existing GRUB entry still boots.

9. **Stage the Qualcomm firmware (optional)**

   Plug in the stick holding the `firmware/` directory from `copy-qcom-firmware.ps1`, run on
   **this** laptop's Windows. The blobs are signed per model.

   - The installer scans attached filesystems for it and places each blob at the path the board's
     device tree names.
   - When Windows has several copies of a name, it takes the newest by the manifest's
     `LastWriteUtc`, and never the NPU package's (`qcnspmcdm*`) when another copy exists.
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

