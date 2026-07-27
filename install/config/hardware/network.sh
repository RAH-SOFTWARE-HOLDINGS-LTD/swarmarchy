# Ensure iwd service will be started
sudo systemctl enable iwd.service

# Prevent systemd-networkd-wait-online timeout on boot
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service

# The .network file that lets networkd track the wireless link — without which
# ONLINE_STATE never leaves "offline" and timesyncd never polls — is a file now:
# system/etc/systemd/network/25-wlan-iwd.network.
sudo systemctl enable systemd-timesyncd.service
