# Path B build plan — distributable aarch64 ISO

The actionable plan for `swarmarchy-iso`. Strategy/background lives in
[`06-custom-iso.md`](./06-custom-iso.md); this is what to *do*, in order.

**Goal:** a `dd`-able ISO that reproduces this exact machine (Yoga Slim 7x, Snapdragon X
Elite) with no install-time prompts.

---

## Repo state (verified 2026-07-20)

- **Work happens on branch `rename-swarmarchy`**, NOT `master`.
  - `master` is unmodified upstream `omarchy-iso` (x86_64). Checking it will mislead you.
  - `convert-to-sway-arm` is the earlier subset; `rename-swarmarchy` supersedes it.
- Already done on that branch (8 commits):
  - `configs/profiledef.sh` — `arch=aarch64`, `bootmodes=('uefi.grub')`, x86 BCJ filter dropped
  - `builder/build-iso.sh` — `ARCH` var, `linux`→`linux-aarch64`, x86 packages stripped, Node `linux-arm64`
  - `configs/pacman-online-*.conf` — Arch Linux ARM mirror, `archlinuxarm-keyring`
  - `.github/workflows/build-iso.yml` — native `ubuntu-24.04-arm` runner
- Open blockers tracked in `swarmarchy-iso/BUILD-AARCH64.md`:
  - **#2** AUR-only packages have no repo to come from
  - **#3** archiso `releng` is x86_64-only — the big unknown

## Locked decisions

- **Installer target: archinstall → Limine + Btrfs + Snapper.**
  - ext4 + GRUB in [`05`](./05-install-on-yoga.md) was the *bootstrap*, not the destination
    (see 05:149 — Btrfs needs `btrfs-progs` in initrd + Limine). The ISO is where the real
    scheme gets done.
- **Disk: dual-boot only.** Preserve Windows, reuse its existing ESP.
  - Keeps the Qualcomm firmware source present on the target machine.
- **AUR package repo: Cloudflare R2 + rclone**, shaped like `omarchy-pkgs`.
  - Omarchy builds PKGBUILDs → GPG-signs → `rclone` syncs a `{channel}/{arch}/` tree.
  - `bin/swarmarchy-iso-rclone-config` already configures `type = s3 / provider = Cloudflare`.
- **Firmware: staged onto the USB at image-build time.**
  - Run `copy-qcom-firmware.ps1` on Windows, then [`05`](./05-install-on-yoga.md) §1.1 bakes
    the result into the image. Installer auto-detects and copies it in. No prompts.

## What does NOT need solving

- **Kernel + DTB.** Stock ALARM `linux-aarch64` (7.1.3 as of writing) is in `core` and ships
  `qcom/x1e80100-lenovo-yoga-slim7x.dtb`. No custom kernel, nothing to bundle.
- **GPU.** `mesa` + `vulkan-freedreno` (turnip) cover Adreno X1-85, both in tree.
- **A custom base mirror.** ALARM serves everything except the AUR packages listed below.
  - `BUILD-AARCH64.md` blocker #2 and `plans/aarch64-support.md` prerequisite #2 both assume
    `pkgs.omarchy.org/*/aarch64/` is needed — it is not. The omarchy repo is gated off on
    aarch64 (see [`05`](./05-install-on-yoga.md) Step 2, "Install gotchas").

## The 18 AUR packages

Everything else resolves from ALARM. `displaylink` / `evdi-dkms` are deliberately dropped.

```
walker  yay  elephant  elephant-calc  elephant-clipboard
elephant-desktopapplications  elephant-files  elephant-menus
elephant-providerlist  elephant-symbols  elephant-websearch
mise-bin  ttf-ia-writer  tzupdate  ufw-docker
xdg-terminal-exec  yaru-icon-theme
```

---

## Build order

### Step 1 — Find out where the build actually dies ✅ RESOLVED (2026-07-20)

Blocker #3 gates everything and was unknown until exercised. Ran it natively on the laptop:

```sh
SWARMARCHY_MIRROR=stable ARCH=aarch64 ./bin/swarmarchy-iso-make --no-boot-offer
```

**The big question — "does mkarchiso work on aarch64?" — is answered: YES.** We keep
mkarchiso; **archboot is NOT needed.** Two walls hit and fixed along the way:

1. **Container was x86.** `bin/swarmarchy-iso-make` hardcoded `archlinux/archlinux:latest`
   (amd64-only) → `exec format error` on the ARM host. Fixed: `ARCH`-aware image select,
   `menci/archlinuxarm:latest` + `--platform linux/arm64` for aarch64. (The plan's
   `archlinuxarm/archlinuxarm` image does **not exist** on Docker Hub — use `menci`.)
2. **`archiso` isn't in ALARM.** `pacman -Sy archiso` → `target not found`. But the package
   is **`arch=any`** — `mkarchiso` is a pure bash script that runs fine on aarch64. Fixed in
   `builder/build-iso.sh`: pull the `any` package from a regular Arch mirror
   (`geo.mirror.pkgbuild.com/extra/os/x86_64/archiso-*-any.pkg.tar.zst`) via `pacman -U`.
   Also added `--disable-sandbox` to every pacman call (host kernel predates Landlock, same
   as the manual install).

Next frontier is the `pacman -Syw` offline-mirror step — where blocker #2 (the AUR packages
have no repo) bites. That's Step 2's job.

**Confirmed reached (2026-07-20):** with the fixes above, the build runs mkarchiso, clones the
installer (via `LOCAL_SOURCE=1 SWARMARCHY_PATH=~/.local/share/swarmarchy`, so it builds the
`rename-swarmarchy` working tree — `master` lacks the renamed `swarmarchy-*` bins), resolves the
full package set, and dies exactly at `pacman -Syw` with:

```
error: target not found: limine-mkinitcpio-hook
error: target not found: limine-snapper-sync
```

So the **not-in-ALARM list is bigger than the 18 below** — those two Limine hooks aren't in it.
**First Step-2 task: enumerate the COMPLETE not-in-ALARM set** by checking every package in the
installer's `swarmarchy-base.packages` + `swarmarchy-other.packages` against the ALARM repos, not
just the AUR packages already installed on this laptop. Invocation that reaches this point:

```sh
LOCAL_SOURCE=1 SWARMARCHY_PATH=~/.local/share/swarmarchy \
  SWARMARCHY_MIRROR=stable ARCH=aarch64 ./bin/swarmarchy-iso-make --no-boot-offer
```

### Step 2 — Stand up `swarmarchy-pkgs`

Kills blocker #2. Independent of Step 1, so do it while that build churns.

- Mirror the `omarchy-pkgs` layout: `pkgbuilds/<pkg>/`, `build-output/{channel}/{arch}/`.
- Build natively with `makepkg` (this machine is aarch64 — no QEMU needed, unlike omarchy's
  x86 build hosts).
- Index and sign:

```sh
repo-add -s -v swarmarchy.db.tar.zst *.pkg.tar.zst
```

- Sync to R2:

```sh
rclone copy build-output/stable/aarch64/ Swarmarchy:swarmarchy-pkgs/stable/aarch64/ -P
```

- Then add one section to `configs/pacman-online-*.conf`:

```ini
[swarmarchy]
Server = https://pkgs.<your-domain>/$repo/aarch64
```

### Step 3 — Swap the base mirror to HTTPS

- Current configs use plain HTTP:

```ini
Server = http://mirror.archlinuxarm.org/$arch/$repo
```

- `public-repo.com` mirrors ALARM with an **identical path layout**, over HTTPS:

```ini
Server = https://public-repo.com/archlinuxarm/$arch/$repo
Server = http://mirror.archlinuxarm.org/$arch/$repo
```

- Keep the ALARM line as fallback.
  - Their AUP asks people not to bulk-pull the tree to seed another mirror. Installer
    `pacman.conf` traffic is fine; the offline-mirror `pacman -Syw` step is the one to point
    at ALARM instead.
  - It is a **read-only** mirror — no uploads, no signup. It cannot host `swarmarchy-pkgs`.

### Step 4 — Firmware staging

- Extend [`05`](./05-install-on-yoga.md) §1.1 image build to copy `qcom-firmware/` into the image.
- Installer side: detect the staged directory and drop it at the board path:

```sh
/lib/firmware/qcom/x1e80100/LENOVO/83ED/
```

- Contents: `qcadsp8380.mbn`, `adsp_dtbs.elf`, `qccdsp8380.mbn`, `cdsp_dtbs.elf`,
  `qcdxkmsuc8380.mbn`.
- Licensing blocks redistribution — this is why it is staged per-machine and never baked
  into a published ISO.

### Step 5 — Configurator

- `configs/airootfs/root/configurator` — archinstall JSON currently assumes a whole-disk
  Btrfs layout.
- Change to: dual-boot, reuse the existing Windows ESP, Btrfs root in free space.
- Verify Limine installs to the shared ESP without disturbing the Windows boot entry.

### Step 6 — Rewrite docs/06

- Fold in what Path A settled (kernel/DTB/GPU all resolved) and point at this file.

---

## Settled logistics (was "open questions")

- **Hosting: user's own Cloudflare account.** R2 + rclone, as omarchy does.
  - **No custom domain needed to start** — an R2 bucket's free `*.r2.dev` URL works as a pacman
    `Server =` line. A domain (`pkgs.swarmarchy.org`) is optional polish for later; `r2.dev` is
    rate-limited / "not for production", so buy the domain only when installs actually hit it.
  - The inherited `bin/swarmarchy-iso-rclone-config` still points at omarchy's bucket +
    1Password paths (`op://Shared/Cloudflare Buckets/iso.omarchy.org/…`, `--account Swarmarchy`).
    **Repoint it at the user's bucket/credentials as part of Step 2** — do not reuse as-is.
- **Working copy: `~/.local/share/swarmarchy-iso`** (beside the installer repo), on branch
  `rename-swarmarchy`. Not scratchpad — that's session-temporary.

## References

- `swarmarchy-iso/BUILD-AARCH64.md` — live blocker tracking
- `swarmarchy-iso/plans/aarch64-support.md` — file-by-file port plan (11 changes)
- [`05-install-on-yoga.md`](./05-install-on-yoga.md) — Path A, the known-good manual install
- [omarchy-pkgs](https://github.com/omacom-io/omarchy-pkgs) — the repo-hosting model we copy
