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
> - **All ISO work is on branch `rename-swarmarchy`**, not `master` (which is untouched
>   upstream `omarchy-iso`).

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
