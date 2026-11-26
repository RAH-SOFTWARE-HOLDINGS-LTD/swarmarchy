# One-shot setup that needs the user's login session (user systemd, gsettings,
# notifications), so it cannot run during the install itself. Run by
# swarmarchy-first-run, after battery-monitor.sh and before firewall.sh/wifi.sh.
# Every section is a line or two, so they share this file. `welcome` is last so its
# notification lands before the Wi-Fi/update one from wifi.sh.

# ─── Display ──────────────────────────────────────────────────────────────────
systemctl --user enable swarmarchy-recover-internal-monitor.service

# ─── Sudoers ──────────────────────────────────────────────────────────────────
if sudo test -f /etc/sudoers.d/99-swarmarchy-installer-reboot; then
  sudo rm -f /etc/sudoers.d/99-swarmarchy-installer-reboot
fi

# ─── DNS ──────────────────────────────────────────────────────────────────────
# https://wiki.archlinux.org/title/Systemd-resolved
echo "Symlink resolved stub-resolv to /etc/resolv.conf"

sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# ─── GTK ──────────────────────────────────────────────────────────────────────
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
# Adwaita icon theme (from gnome-themes-extra); Yaru was dropped on aarch64 (no repo source).
gsettings set org.gnome.desktop.interface icon-theme "Adwaita"

gsettings set org.gnome.desktop.interface gtk-enable-primary-paste true

# ─── User services ────────────────────────────────────────────────────────────
systemctl --user daemon-reload
systemctl --user enable --now swayosd-server.service
systemctl --user enable --now swayidle.service
# Start oo7-daemon with the session so the keyring is unlocked before any app asks:
# by default it unlocks itself at startup (oo7-daemon.service.d/no-password.conf);
# with `swarmarchy toggle keyring-password on`, PAM's session phase hands it the
# login password and must find it already starting. A locked Secret Service makes
# Chromium-based browsers hang on every page load. See install/login/greetd.sh.
systemctl --user enable oo7-daemon.service

elephant service enable
systemctl --user start elephant.service

# ─── Podman ───────────────────────────────────────────────────────────────────
# podman.socket is the Docker-compatible API (DOCKER_HOST in default/bash/envs
# points at it); podman-restart.service brings back containers started with
# --restart after a reboot.
# Only when Podman was chosen at install time.
if command -v podman &>/dev/null; then
  systemctl --user enable --now podman.socket
  systemctl --user enable podman-restart.service
fi

# ─── Welcome ──────────────────────────────────────────────────────────────────
notify-send "    Learn Keybindings" "Super + M for keybindings.\nSuper + Space for the Swarmarchy menu." -u critical
