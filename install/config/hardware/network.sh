# Ensure iwd service will be started
sudo systemctl enable iwd.service

# Prevent systemd-networkd-wait-online timeout on boot
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service

# Let networkd track the wireless link so it counts toward ONLINE_STATE.
#
# iwd does its own DHCP, so without a matching .network file networkd leaves
# wlan0 unmanaged and reports ONLINE_STATE=offline even while the link is
# routable. systemd-timesyncd only polls once the system is considered online,
# so it sits idle forever: "System clock synchronized: no" with a packet count
# of 0, and the clock free-runs on the RTC.
#
# DHCP=no with KeepConfiguration=yes means networkd tracks the link without
# touching iwd's addressing.
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

sudo systemctl enable systemd-timesyncd.service
