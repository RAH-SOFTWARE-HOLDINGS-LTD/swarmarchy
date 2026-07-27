if swarmarchy-battery-present; then
  cat <<EOF | sudo tee "/etc/udev/rules.d/99-wifi-powersave.rules"
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="/usr/bin/systemd-run --no-block --collect --unit=swarmarchy-wifi-powersave-on /usr/lib/swarmarchy/bin/swarmarchy-wifi-powersave on"
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/bin/systemd-run --no-block --collect --unit=swarmarchy-wifi-powersave-off /usr/lib/swarmarchy/bin/swarmarchy-wifi-powersave off"
EOF

  sudo udevadm control --reload
  sudo udevadm trigger --subsystem-match=power_supply
fi
