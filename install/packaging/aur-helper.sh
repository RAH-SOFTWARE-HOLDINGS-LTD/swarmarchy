# Bootstrap the yay AUR helper.
# Packages that are AUR-only on a generic Arch ARM base (walker, the elephant stack,
# mise-bin, ...) need yay available before base.sh runs.

# The [swarmarchy] aarch64 package repo. Overridable so the bucket is not hardcoded
# in both this repo and swarmarchy-iso's pacman-online-*.conf.
SWARMARCHY_PKG_URL="${SWARMARCHY_PKG_URL:-https://pub-94007937245e4d81848717760f9dfc75.r2.dev/stable/$(uname -m)}"

# Resolve yay's exact package filename from the repo database. It must be read, not
# constructed: the published package is .pkg.tar.xz, so assuming .pkg.tar.zst would
# 404. %FILENAME% is the first field of each package's `desc` entry.
swarmarchy_repo_yay_filename() {
  curl -fsSL "$SWARMARCHY_PKG_URL/swarmarchy.db" |
    tar -xzOf - --wildcards 'yay-*/desc' 2>/dev/null |
    sed -n '/%FILENAME%/{n;p}' |
    head -n1
}

# yay is prebuilt for aarch64 in the [swarmarchy] repo. Building it from the AUR needs
# `go`, a git clone of aur.archlinux.org and a working network -- none of which exist
# during an offline ISO install, where this used to fail with "target not found: go"
# and take every later AUR package down with it (including greetd, so the machine
# came up with no login manager at all). So: repo, then the repo's package over HTTP,
# then source build.
if ! command -v yay &>/dev/null; then
  # 1. From a configured repo ([swarmarchy], as the ISO's pacman.conf sets up).
  if ! sudo pacman -S --noconfirm --needed yay; then
    # 2. Straight from the repo's package file, for an install.sh run by hand against
    #    a pacman.conf that does not have [swarmarchy] in it. The repo is unsigned
    #    (SigLevel = Optional TrustAll); `pacman -U` accepts that because
    #    LocalFileSigLevel is Optional.
    echo "yay not available from a configured repo; trying $SWARMARCHY_PKG_URL" >&2
    yay_file=$(swarmarchy_repo_yay_filename)

    if [[ -z $yay_file ]] ||
      ! sudo pacman -U --noconfirm "$SWARMARCHY_PKG_URL/$yay_file"; then
      # 3. Build it.
      echo "falling back to building yay from the AUR" >&2
      sudo pacman -S --noconfirm --needed base-devel git go

      build_dir=$(mktemp -d)
      git clone --depth 1 https://aur.archlinux.org/yay.git "$build_dir/yay"
      (cd "$build_dir/yay" && makepkg -si --noconfirm)
      rm -rf "$build_dir"
    fi
  fi
fi

# walker is listed in swarmarchy-base.packages and normally comes from the repo; this
# is only a safety net for installs whose repo lacks it.
if ! command -v walker &>/dev/null; then
  yay -S --noconfirm --needed walker
fi
