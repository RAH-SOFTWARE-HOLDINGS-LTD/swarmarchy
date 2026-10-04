# Bootstrap the yay AUR helper.
# Packages that are AUR-only on a generic Arch ARM base (walker, bluetui, impala,
# wiremix, swayosd, ...) need yay available before base.sh runs.

# Prefer the prebuilt yay from the swarmarchy repo. Building it from the AUR needs
# `go`, a git clone of aur.archlinux.org and a working network -- none of which exist
# during an offline ISO install, where this used to fail with "target not found: go"
# and take every later AUR package down with it (including greetd, so the machine
# came up with no login manager at all).
if ! command -v yay &>/dev/null; then
  if ! sudo pacman -S --noconfirm --needed yay; then
    echo "yay not available from a repo; falling back to building it from the AUR" >&2
    sudo pacman -S --noconfirm --needed base-devel git go

    build_dir=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay.git "$build_dir/yay"
    (cd "$build_dir/yay" && makepkg -si --noconfirm)
    rm -rf "$build_dir"
  fi
fi

# walker is listed in swarmarchy-base.packages and normally comes from the repo; this
# is only a safety net for installs whose repo lacks it.
if ! command -v walker &>/dev/null; then
  yay -S --noconfirm --needed walker
fi
