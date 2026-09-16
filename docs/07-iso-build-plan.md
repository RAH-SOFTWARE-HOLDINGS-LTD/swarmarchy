# Path B build plan — distributable aarch64 ISO

The actionable plan for `swarmarchy-iso`. Strategy/background lives in
[`06-custom-iso.md`](./06-custom-iso.md); this is what to *do*, in order.

**Goal:** a `dd`-able ISO that reproduces this exact machine (Yoga Slim 7x, Snapdragon X
Elite) with no install-time prompts.

---

## Where we are (2026-09-14)

| Step | State |
|---|---|
| 1 — Get the build running | ✅ done |
| 2 — `swarmarchy-pkgs` on R2 | ✅ done (18 packages live) |
| 3 — Swap base mirror to HTTPS | ✅ closed as **no-op** — keep ALARM over HTTP |
| 4 — Firmware staging | ✅ code done, not hardware-tested |
| 5 — Configurator / dual-boot | ✅ code done, not hardware-tested |
| 6 — Rewrite `docs/06` | ⬜ not started |

**Current step: the first real install on hardware.** All the installer code is written; nothing
more can be proven without running it.

- **Blocked on:** free space. Shrink the ext4 root to leave ≥21 GiB unallocated (20 root + 1 ESP);
  ~100 GiB recommended. Do it from the swarmarchy ISO's own shell — see Step 5, "Freeing the space".
- **Then:** flash the ISO, boot it, pick "install alongside", and see what breaks.

Known-unfixed, worth reading before trusting a run:

- **The wipe path's Limine install is probably broken on aarch64.** archinstall's
  `_add_limine_bootloader` hardcodes `BOOTIA32.EFI`/`BOOTX64.EFI` and never copies `BOOTAA64.EFI`
  (`installer.py:1497`). The dual-boot path sidesteps this by installing Limine itself; a
  whole-disk wipe install likely will not boot. Not yet fixed.
- **The `swarmarchy-pkgs` repo is unsigned** — `SigLevel = Optional TrustAll`. Sign it before
  anyone else uses this ISO.
- **No custom domain yet**, so no WAF/rate-limit is possible on the bare `r2.dev` URL.

---

## Repo state (verified 2026-07-20)

- **Work happens on `master`** (both repos). The aarch64/rename work was merged there.
  - Historical note: it used to live on `rename-swarmarchy`, and `master` used to be unmodified
    upstream `omarchy-iso`. Both are now the same commit. `git fetch` before judging — a stale
    clone still shows the old upstream `master`.
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
- **Disk: dual-boot only.** Preserve Windows; install into pre-existing free space.
  - **Swarmarchy gets its OWN 1 GiB ESP** (revised 2026-08-26 — the earlier plan reused the
    Windows ESP). Reasons the shared ESP stopped fitting: the layer sets `ENABLE_UKI=yes`, so the
    kernel is stored twice (raw `Image` + initramfs *and* a ~60 MB UKI); firmware-owned
    `Persisted_Capsules.bin` takes ~70 MB of it; `MAX_SNAPSHOT_ENTRIES=5` needs ~300 MB more; and
    a full ESP breaks Windows' own boot writes.
  - A dedicated ESP also means `ENABLE_LIMINE_FALLBACK=yes` writes `EFI/BOOT/BOOTAA64.EFI` on
    *our* partition instead of overwriting a bootloader that already owns the shared one.
  - Nothing is ever shrunk automatically. The user frees the space first.
- **AUR package repo: Cloudflare R2 + rclone**, shaped like `omarchy-pkgs`.
  - Omarchy builds PKGBUILDs → GPG-signs → `rclone` syncs a `{channel}/{arch}/` tree.
  - `bin/swarmarchy-iso-rclone-config` already configures `type = s3 / provider = Cloudflare`.
- **Firmware: user-staged, provisioned at install time (never baked into the published ISO).**
  - Run `copy-qcom-firmware.ps1` on Windows → a `firmware/` dir; drop it on a USB partition. The
    installer auto-detects the staged dir and drops the blobs at the board path. No prompts.
    Does NOT read the Windows partition — user-staged only. See Step 4.

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
installer (via `LOCAL_SOURCE=1 SWARMARCHY_PATH=~/.local/share/swarmarchy`, so it builds the local
working tree rather than a fetched ref), resolves the
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

### Step 3 — Swap the base mirror to HTTPS ✅ CLOSED — no-op (2026-07-24)

**Decision: keep the official ALARM mirror over HTTP. Change nothing.**

- The entire official ALARM network is HTTP-only — all 13 mirrors, including the geo redirector
  `mirror.archlinuxarm.org`. There is no official HTTPS ALARM mirror.
- Transport does not carry the integrity guarantee anyway. `pacman-online-*.conf` already sets:

```ini
SigLevel = Required DatabaseOptional
```

  - Every package is GPG-verified against `archlinuxarm-keyring`, so HTTP cannot inject one that
    passes the signature check.
- HTTPS would add only privacy and hostile-network compatibility — not worth baking an obscure
  single-origin third party (`public-repo.com`, `cdnmirror.com`) into the base of a
  *distributable* installer.
- Any end user who wants HTTPS changes one line.

### Step 4 — Firmware staging ✅ DONE (2026-07-25)

**Design refined from the original bullet.** "Copy `firmware/` into the image" doesn't fit a
`dd`-ed ISO9660 — the medium is read-only, so nothing can be injected post-build, and licensing bars
baking it into the *published* ISO anyway. Instead the firmware is **user-staged** and provisioned
**at install time**:

- The user runs [`copy-qcom-firmware.ps1`](./copy-qcom-firmware.ps1) on Windows to collect the blobs
  into a `firmware/` directory, then drops that directory onto any disk attached at install time
  (a second partition on the USB, or a second stick).
- The installer scans attached filesystems for that staged `firmware/` dir (identified by the
  `.ps1`'s `MANIFEST.csv`, then confirmed by actually finding the blobs inside).

Deliberately does NOT read the firmware out of the Windows partition — user-staged only, per the
locked decision. Implemented as `configs/airootfs/usr/local/bin/swarmarchy-stage-qcom-firmware`
(registered in `profiledef.sh`), called at the end of `install_base_system` in
`.automated_script.sh` as `swarmarchy-stage-qcom-firmware /mnt`. It finds the five blobs by name
across scattered staged subfolders and places them **flattened** at the board path:

```sh
/lib/firmware/qcom/x1e80100/LENOVO/83ED/
# qcadsp8380.mbn  adsp_dtbs.elf  qccdsp8380.mbn  cdsp_dtbs.elf  qcdxkmsuc8380.mbn
```

The bulk copy alone doesn't land them here — this exact path is what the `msm` (GPU/display) and
`remoteproc` (ADSP/CDSP → Type-C DP-alt monitors + audio) drivers probe (see
[`05`](./05-install-on-yoga.md) §"External monitors"). Best-effort and **non-fatal**: it board-gates
on `x1e80100` in the DT compatible and no-ops on other hardware, and if no source is found it warns
and lets the install finish.

**NOT YET hardware-tested** — flatten/place logic is unit-tested; the block-device scan for the
staged `firmware/` dir needs a real Yoga install run to confirm.

### Step 5 — Configurator / dual-boot ✅ CODE DONE (2026-08-26)

Committed as `43b3af3` in `swarmarchy-iso`. The installer used to only wipe a whole disk; it now
offers an "install alongside" path. Two halves:

**a) `configs/airootfs/root/configurator` — pick the mode, write the config**

- Finds the largest free region (`parted -ms … print free`) and offers alongside-vs-wipe only when
  it fits a 1 GiB ESP plus a 20 GiB root.
- For the alongside path, emits an archinstall config with:

```json
"bootloader": "No bootloader",
"disk_config": { "config_type": "pre_mounted_config", "mountpoint": "/mnt" }
```

  - `pre_mounted_config` makes archinstall skip `mount_ordered_layout()` entirely and adopt
    whatever tree we mounted (`guided.py:86`); `genfstab` still runs (`guided.py:184`).
  - `"No bootloader"` makes it skip `add_bootloader()` (`guided.py:117`) so it never writes to an
    ESP — **but it is only an accepted value when archinstall is also passed `--skip-boot`**
    (`bootloader.py:53`), which `.automated_script.sh` now does unconditionally.
- Hands the target geometry over in `user_install_mode.txt` + `user_dualboot.env`.
- The wipe path's generated JSON is byte-identical to before.

**b) `configs/airootfs/root/.automated_script.sh` — do the work archinstall no longer does**

- Creates a **1 GiB ESP and a Btrfs root** in the free region, lays out `@`, `@home`, `@log`,
  `@pkg`, `@snapshots`, mounts the tree with `compress=zstd,noatime`.
- Installs Limine to `EFI/swarmarchy` on our own ESP and registers it with `efibootmgr`,
  **appending** to the existing boot order rather than taking it over.
- Writes `limine.conf` at the **ESP root**, not next to the binary.
  - Limine checks `<EFI app path>/limine.conf` first, then scans the ESP for `/limine.conf`.
  - Since the ESP is mounted at `/boot`, that file *is* `/boot/limine.conf` — the one path the
    layer's `install/login/limine-snapper.sh` both finds and deliberately preserves. It exits 1
    if it finds no config, and deletes configs found anywhere else.
- Keeps only this board's device tree on the ESP via `NoExtract`; `linux-aarch64` ships ~120 MiB
  of DTBs and the kernel must sit on FAT for Limine to read it at all.
- Configures Snapper, which `pre_mounted_config` skips.
- Skips `cleanup_install_disk` in this mode — it releases holders across the *whole* disk.

**Tested** against synthetic loopback disks: partitioning, subvolumes, mount tree, bootloader
placement, boot-order handling, and sentinel files proving pre-existing ESP contents survive.
**Not hardware-tested.**

#### Freeing the space (user does this first)

The installer only ever *adds* partitions into space that is already free; it never shrinks
anything. The user frees it first, from the ISO's own shell.

- Full boot-to-install runbook: [`06`](./06-custom-iso.md) §"Running the installer".
- No GParted needed — it has no aarch64 build, and the ISO already ships `e2fsprogs`, `parted`,
  `fdisk`/`sfdisk`/`cfdisk`, `gdisk`/`sgdisk` and `ntfsresize`.
- Minimum to unlock the alongside option: **21 GiB** free (20 root + 1 ESP).

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

### Step 6 — Rewrite docs/06 ⬜ NOT STARTED

- Fold in what Path A settled (kernel/DTB/GPU all resolved) and point at this file.
- Do this **after** the first successful hardware install, so it documents what actually happened
  rather than what was planned.

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
- **Working copy: `~/.local/share/swarmarchy-iso`** (beside the installer repo), on `master`.
  Not scratchpad — that's session-temporary.

## References

- `swarmarchy-iso/BUILD-AARCH64.md` — live blocker tracking
- `swarmarchy-iso/plans/aarch64-support.md` — file-by-file port plan (11 changes)
- [`05-install-on-yoga.md`](./05-install-on-yoga.md) — Path A, the known-good manual install
- [omarchy-pkgs](https://github.com/omacom-io/omarchy-pkgs) — the repo-hosting model we copy
