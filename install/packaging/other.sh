# Install the aarch64 foundation/userland packages from swarmarchy-other.packages.
#
# This manifest doubles as the ISO's offline-mirror seed, so it also lists things
# the base-install and boot phases already own on their own: the kernel (`linux`,
# which is `linux-aarch64` on ALARM) and the limine snapshot hooks that only live
# in the AUR. Those don't resolve with a plain post-install `pacman -S` on aarch64,
# so we skip any entry that isn't in an official aarch64 repo (nor already
# installed) and let the phase that owns it handle it. `--needed` (inside
# swarmarchy-pkg-add) makes the already-present base packages no-ops, so the net
# effect on a normal install is: pull in the userland the base phase didn't
# (pipewire-alsa/jack, gst-plugin-pipewire, qt6-wayland, webp-pixbuf-loader, ...).

manifest="$SWARMARCHY_INSTALL/swarmarchy-other.packages"
mapfile -t wanted < <(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$manifest" | awk '{print $1}')

install=()
skipped=()
for pkg in "${wanted[@]}"; do
  if pacman -Q "$pkg" &>/dev/null || pacman -Si "$pkg" &>/dev/null; then
    install+=("$pkg")
  else
    skipped+=("$pkg")
  fi
done

if ((${#skipped[@]})); then
  echo "swarmarchy-other: skipping (not in aarch64 repos; owned by base/boot phase): ${skipped[*]}"
fi

if ((${#install[@]})); then
  swarmarchy-pkg-add "${install[@]}"
fi
