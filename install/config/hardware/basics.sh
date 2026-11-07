# Baseline hardware services: networking, Bluetooth and the power button.
# Each is a few lines, so they share a file; hardware that needs real logic
# (printer, regdom, suspend, usb) keeps its own.

# ─── Network ──────────────────────────────────────────────────────────────────
# Ensure iwd service will be started
sudo systemctl enable iwd.service

# Prevent systemd-networkd-wait-online timeout on boot
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service

# Hand addressing to iwd and get systemd-networkd out of the way entirely.
#
# archinstall now runs with "network_config": {"type": "iwd"} (swarmarchy-iso), so the
# live archiso 20-wlan.network is no longer copied into the target. This step stays as
# the backstop: archinstall enables systemd-networkd in EVERY mode except NetworkManager,
# so even standalone-iwd leaves the units enabled. system/etc/iwd/main.conf sets
# EnableNetworkConfiguration=true so iwd does its own DHCP and feeds DNS to resolved.
#
# Verified by bisect, not assumed: with networkd disabled and main.conf in place, a boot
# logs 0 USB enumeration errors. Re-enabling networkd and removing main.conf brought back
# 8 errors on the same kernel and hardware -- "device not accepting address, error -62"
# retrying every ~11s until "unable to enumerate USB device". Restoring the config cleared
# them again. Do not drop this loop without repeating that test.
#
# Not cosmetic: networkd brings up every link it matches, including a dock's USB
# ethernet. On the Yoga Slim 7x that adapter shares a USB hub with the keyboard and
# mouse, and its carrier flapping at boot is followed ~600ms later by the entire hub
# chain dropping off the bus with -62/-71.
for unit in systemd-networkd.service systemd-networkd.socket \
            systemd-networkd-varlink.socket systemd-networkd-varlink-metrics.socket \
            systemd-networkd-resolve-hook.socket systemd-network-generator.service; do
  sudo systemctl disable "$unit" 2>/dev/null || true
done

# The .network file that lets networkd track the wireless link — without which
# ONLINE_STATE never leaves "offline" and timesyncd never polls — is a file now:
# system/etc/systemd/network/25-wlan-iwd.network.
sudo systemctl enable systemd-timesyncd.service

# ─── Bluetooth ────────────────────────────────────────────────────────────────
# Turn on bluetooth by default
chrootable_systemctl_enable bluetooth.service

mkdir -p ~/.config/wireplumber/wireplumber.conf.d/
cp "$SWARMARCHY_PATH/default/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf" ~/.config/wireplumber/wireplumber.conf.d/

# ─── Power button ─────────────────────────────────────────────────────────────
# Disable shutting system down on power button to bind it to power menu afterwards
sudo sed -i 's/.*HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf
