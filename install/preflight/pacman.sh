if [[ -n ${SWARMARCHY_ONLINE_INSTALL:-} ]]; then
  # Install build tools
  swarmarchy-pkg-add base-devel

  # Refresh all repos. The pacman.conf the ISO shipped already names the Arch Linux
  # ARM mirrors plus the [swarmarchy] aarch64 package repo, so there is nothing to
  # reconfigure here.
  sudo pacman -Syyuu --noconfirm
fi
