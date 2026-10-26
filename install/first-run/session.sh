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

elephant service enable
systemctl --user start elephant.service

# ─── Podman ───────────────────────────────────────────────────────────────────
# podman.socket is the Docker-compatible API (DOCKER_HOST in default/bash/envs
# points at it); podman-restart.service brings back containers started with
# --restart after a reboot.
systemctl --user enable --now podman.socket
systemctl --user enable podman-restart.service

# ─── Welcome ──────────────────────────────────────────────────────────────────
notify-send "    Learn Keybindings" "Super + K for cheatsheet.\nSuper + Space for application launcher.\nSuper + Alt + Space for Swarmarchy Menu." -u critical
