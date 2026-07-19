# Configure pacman.
# The default pacman-*.conf / mirrorlist-* point at Omarchy's x86_64 mirrors
# (stable-mirror.omarchy.org, [multilib], the [swarmarchy] repo) — none exist for
# aarch64. On ARM, leave the existing Arch Linux ARM mirror + pacman.conf untouched.
if [[ "$(uname -m)" == "x86_64" ]]; then
  sudo cp -f ~/.local/share/swarmarchy/default/pacman/pacman-${SWARMARCHY_MIRROR:-stable}.conf /etc/pacman.conf
  sudo cp -f ~/.local/share/swarmarchy/default/pacman/mirrorlist-${SWARMARCHY_MIRROR:-stable} /etc/pacman.d/mirrorlist
fi

if lspci -nn | grep -q "106b:180[12]"; then
  cat <<EOF | sudo tee -a /etc/pacman.conf >/dev/null

[arch-mact2]
Server = https://github.com/NoaHimesaka1873/arch-mact2-mirror/releases/download/release
SigLevel = Never
EOF
fi
