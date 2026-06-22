# Bootstrap the yay AUR helper.
# Going generic (no omarchy package repo) means packages like walker, bluetui, impala,
# wiremix, swayosd, etc. come from the AUR — so swarmarchy-pkg-add needs yay available
# before base.sh runs. (makepkg must run as the unprivileged user, not root.)

if ! command -v yay &>/dev/null; then
  sudo pacman -S --noconfirm --needed base-devel git go

  build_dir=$(mktemp -d)
  git clone --depth 1 https://aur.archlinux.org/yay.git "$build_dir/yay"
  (cd "$build_dir/yay" && makepkg -si --noconfirm)
  rm -rf "$build_dir"
fi

# The keyboard-first launcher (walker) is AUR-only on a generic Arch ARM base; install it
# here so it's present before config/walker-elephant.sh wires it up. (Other AUR packages
# in swarmarchy-base.packages are handled by swarmarchy-pkg-add's yay fallback in base.sh.)
yay -S --noconfirm --needed walker
