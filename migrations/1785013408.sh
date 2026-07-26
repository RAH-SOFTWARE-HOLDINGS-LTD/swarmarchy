echo "Let networkd track the wireless link so systemd-timesyncd starts syncing"

# iwd does its own DHCP, so networkd left wlan0 unmanaged and reported
# ONLINE_STATE=offline. timesyncd only polls once the system is online, so
# existing installs have been free-running on the RTC: "System clock
# synchronized: no" with a timesyncd packet count of 0.
#
# DHCP=no with KeepConfiguration=yes means networkd tracks the link without
# touching iwd's addressing.

if [[ ! -f /etc/systemd/network/25-wlan-iwd.network ]]; then
  sudo tee /etc/systemd/network/25-wlan-iwd.network >/dev/null <<EOF
[Match]
Name=wlan*

[Network]
DHCP=no
LinkLocalAddressing=no
KeepConfiguration=yes

[Link]
RequiredForOnline=routable
EOF

  sudo networkctl reload
fi

sudo systemctl enable --now systemd-timesyncd.service
