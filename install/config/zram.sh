# Enable compressed RAM swap (zram). The zram-generator package is installed but
# does nothing without a config; this drops one in so a /dev/zram0 swap device is
# created on boot. Coexists with the hibernation swapfile (zram is higher priority
# and used first; disk swap stays as overflow / for hibernation where supported).
sudo cp "$SWARMARCHY_PATH/default/systemd/zram-generator.conf" /etc/systemd/zram-generator.conf
sudo install -Dm644 "$SWARMARCHY_PATH/default/sysctl/99-swarmarchy-zram.conf" \
  /etc/sysctl.d/99-swarmarchy-zram.conf

# Apply the sysctls now; the zram device itself comes up on next boot (or via
# `systemctl start systemd-zram-setup@zram0.service`).
sudo sysctl --system >/dev/null 2>&1 || true
