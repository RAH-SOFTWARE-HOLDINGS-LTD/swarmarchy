# Baseline hardware services: networking, Bluetooth and the power button.
# Each is a few lines, so they share a file; hardware that needs real logic
# (printer, regdom, suspend, usb) keeps its own.

# ─── Network ──────────────────────────────────────────────────────────────────
# Ensure iwd service will be started
sudo systemctl enable iwd.service

# Prevent systemd-networkd-wait-online timeout on boot
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service

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
