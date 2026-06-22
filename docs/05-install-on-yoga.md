# Path A — Install swarmarchy on the Yoga (base Arch ARM + the layer)

The fastest, lowest-risk way onto the Yoga Slim 7x (Snapdragon X Elite). swarmarchy is a
**post-install layer**, so you don't need the custom ISO (that's Path B / `06`): get a
working **Arch Linux ARM** base booting on the laptop, then run the installer on top.

This sidesteps the hardest blockers (the archiso-aarch64 problem). The genuinely hard
part here is step 1 (bringing up Arch ARM on the device) — and the community already
solved it, so we lean on their guide.

---

## 0. Before you touch the disk (Windows side, dual-boot safe)
- **Back up your BitLocker recovery key** (and ideally suspend BitLocker) — repartitioning
  can otherwise lock you out of Windows.
- **Shrink the Windows partition** from Windows Disk Management (Shrink Volume) to free
  space for Linux. Leave the **Windows + EFI** partitions intact — this is *dual-boot*,
  **no wipe**.
- **Extract the Qualcomm firmware** you'll need on Linux: from
  `C:\Windows\System32\DriverStore\FileRepository\*\*.mbn` / `*.jsn` / `dtbs.elf`. Copy
  them to a USB (the community guides list exactly which files).
- In **UEFI/BIOS**: disable **Secure Boot**.

## 1. Get a base Arch Linux ARM booting (use the community guide)
This is device-specific bring-up — follow the proven guide, don't improvise:
- **Primary — joske's gist (Arch ARM on this exact laptop):**
  https://gist.github.com/joske/52be3f1e5d0239706cd5a4252606644b
- **Reference — kuruczgy's NixOS config** (authoritative kernel/firmware/quirks list):
  https://github.com/kuruczgy/x1e-nixos-config
- **Stepping stone:** Ubuntu's "Concept" ISO (24.10) if you want a known-good boot first.

What must be in place: a recent **mainline/ALARM `linux-aarch64` (6.14+)**, the upstream
**`qcom/x1e80100-lenovo-yoga-slim7x.dtb`**, and the **Qualcomm firmware** (from step 0).
If you want to match swarmarchy's scheme, use **LUKS + Btrfs subvolumes + Limine** — but
any working Arch aarch64 base is fine; the layer doesn't care.

> Known rough edges (verify current state in the guide): early support had flaky
> touchpad, internal mics (DMICs), and battery monitoring.

## 2. Apply the swarmarchy layer
Once you have a booted Arch ARM with networking and your user:
```bash
git clone -b convert-to-sway-arm \
  https://github.com/RAH-SOFTWARE-HOLDINGS-LTD/swarmarchy.git ~/.local/share/swarmarchy
source ~/.local/share/swarmarchy/install.sh
```
(or use `boot.sh` once you point `SWARMARCHY_REPO`/`SWARMARCHY_REF` at your fork+branch.)
This runs the install phases — packages (`swarmarchy-base/other.packages`), config copy,
theme render, login, hardware fixes — and ends at a Sway desktop.

## 3. Handled automatically by the installer (were gotchas)
- **AUR packages:** `install/packaging/aur-helper.sh` bootstraps **yay** and installs
  **walker** before `base.sh`; `swarmarchy-pkg-add` then falls back to yay for any AUR
  package, so walker/bluetui/impala/wiremix/etc. install automatically. (`displaylink`/
  `evdi` stay opt-in — add them if you use the adapter.)
- **Login manager:** `install/login/greetd.sh` sets up **greetd + tuigreet** to launch
  Sway at boot (replaced SDDM) — a graphical login, not a bare TTY.

## Still-known gotchas
- **Hardware-fix scripts:** the x86 ones (intel/nvidia/asus/apple/framework/…) are gated
  on detection and skip on Snapdragon — harmless, but prunable later.
- **Verify on bare metal:** work through **`04-testing.md` Step 7** (media keys,
  brightness, GPU accel, Wi-Fi/BT, DisplayLink, fingerprint) and fix-then-push anything
  broken — the install at `~/.local/share/swarmarchy` is a git clone, so edit → commit →
  `git -C ~/.local/share/swarmarchy pull`.

## References
joske gist · kuruczgy NixOS · Ubuntu Concept · daily-driver writeup
(https://varunpriolkar.com/2025/07/daily-driving-an-arm-linux-laptop/) · and the build
blockers in `swarmarchy-iso/BUILD-AARCH64.md`.
