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

- Sync to R2 (object storage is flat — the object *key* becomes the URL path, so a key of
  `stable/aarch64/walker-….pkg.tar.zst` is served at `<host>/stable/aarch64/walker-….pkg.tar.zst`.
  This is why R2 gives clean `$arch` paths that GitHub Releases can't):

```sh
rclone copy build-output/stable/aarch64/ Swarmarchy:swarmarchy-pkgs/stable/aarch64/ -P
```

- Then add one section to `configs/pacman-online-*.conf` (matches omarchy's `stable/$arch`
  layout; `$arch` → `aarch64`, channel hardcoded per config file):

```ini
[swarmarchy]
Server = https://pkgs.swarmarchy.org/stable/$arch
```

#### R2 hosting notes

- **Bucket:** `swarmarchy-pkgs`. Keys are `stable/aarch64/<file>` — no real folders, the key
  string *is* the path.
- **Two ways to expose it:**
  - `r2.dev` managed subdomain (bucket → Settings → Public access) — free, instant, good for
    testing. `https://pub-<hash>.r2.dev/stable/aarch64/…`. Rate-limited by CF, "not for production."
  - Custom domain (`pkgs.swarmarchy.org` → connect to bucket) — routes through the Cloudflare
    edge. **Required if you want the domain to look right AND to attach protection rules.**
- **⚠️ ABUSE / RATE-LIMIT REMINDER (user asked for this):** the repo is public (as all pacman
  repos are), and R2's zero-egress means download-hammering can't run up a bill — but still add
  protection so nobody uses it as free CDN/file-host:
  - Rules **only apply on a custom domain (or a Worker in front)** — you CANNOT attach custom
    WAF/rate-limit rules to a bare `r2.dev` URL. So step one is "put it on `pkgs.swarmarchy.org`."
  - In the Cloudflare dashboard for that hostname, add:
    - a **Rate Limiting Rule** (free tier allows one) — e.g. >100 req/min from one IP to
      `/stable/*` → managed challenge or block for 10 min.
    - **WAF** managed ruleset (free tier) enabled on the hostname.
    - optionally a **Cache Rule** so repeated package pulls are served from CF cache, not R2
      (cuts R2 Class B ops too).
- **Credentials:** `bin/swarmarchy-iso-rclone-config` still points at omarchy's bucket +
  1Password paths (`op://Shared/Cloudflare Buckets/iso.omarchy.org/…`, `--account Swarmarchy`).
  Repoint to the user's R2 API token + bucket before first sync.

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

#### Btrfs performance tuning (user wants this once Btrfs+Limine works)

Btrfs is chosen for Snapper snapshots + bootloader rollback (Snapper needs Btrfs or LVM-thin;
ext4 has no native snapshots, so "ext4 + Snapper" isn't a real option and ext4+LVM-thin can't
boot-into-snapshot cleanly). Btrfs is slightly heavier than ext4 (CoW bookkeeping, checksums),
but the real-world gap on this NVMe/desktop workload is mostly synthetic. Three tunings close it:

- **`compress=zstd:1`** (fstab mount opt) — transparent compression. Btrfs default is NONE.
  Level 1 = negligible CPU, auto-skips incompressible data. Moves less data (often *faster* I/O)
  and saves 20–40% on text/code/logs. **Safe universal win — set by default in the configurator.**
- **`noatime`** (fstab mount opt) — stop the write-on-read that even `relatime` still does.
  Breaks strict-POSIX atime that a few niche tools (some mail clients) want; harmless on desktop.
  **Safe win — set by default.**
- **`nodatacow` on hot dirs** (`chattr +C` on an EMPTY dir before files land) — disables CoW for
  databases (sqlite), VM images (qcow2), container storage — the exact files where CoW
  fragmentation makes Btrfs feel slow. **CANNOT be a blanket default:** it also disables
  checksums + snapshots + compression for those files (defeats Btrfs), so it's a targeted
  scalpel, and which dirs are "hot" is workload-specific. **Document as opt-in**, suggest
  `chattr +C ~/.local/share/containers`, VM dirs, etc.

Example fstab line the configurator should emit for the root subvol:

```
UUID=<root> /  btrfs  subvol=@,compress=zstd:1,noatime,ssd,space_cache=v2  0 0
```

Why not on by default upstream: archinstall/Arch stay conservative for compatibility/generality
(Fedora *does* ship zstd:1). The safe two should just be on; the scalpel stays manual by nature.

### Step 6 — Rewrite docs/06

- Fold in what Path A settled (kernel/DTB/GPU all resolved) and point at this file.

---

## Settled logistics (was "open questions")

- **Hosting: user's own Cloudflare account.** R2 + rclone, as omarchy does. Free at this scale
  (few hundred MB « 10 GB free tier; zero egress kills the cost-abuse vector). See the "R2
  hosting notes" under Step 2 for the bucket layout, the flat-key→URL-path explanation, and the
  **rate-limit/WAF reminder** (rules need a custom domain — they can't attach to a bare `r2.dev`
  URL).
  - **`r2.dev` URL is fine to START/test** (free, instant) but gets no custom protection rules.
    A custom domain (`pkgs.swarmarchy.org`) is what enables WAF + rate-limiting — so it's less
    "optional polish" and more "needed before this is public-facing for real."
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
