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
