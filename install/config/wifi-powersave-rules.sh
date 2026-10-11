if swarmarchy-battery-present; then
  # Fire on any Mains/USB change and let the script autodetect. USB-C-only
  # laptops (eg. Snapdragon X Elite) never bring the legacy Mains supply
  # online, so a Mains-only rule would pin powersave on permanently.
  cat <<EOF | sudo tee "/etc/udev/rules.d/99-wifi-powersave.rules"
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="/usr/bin/systemd-run --no-block --collect --unit=swarmarchy-wifi-powersave /usr/lib/swarmarchy/bin/swarmarchy-wifi-powersave"
SUBSYSTEM=="power_supply", ATTR{type}=="USB", RUN+="/usr/bin/systemd-run --no-block --collect --unit=swarmarchy-wifi-powersave /usr/lib/swarmarchy/bin/swarmarchy-wifi-powersave"
EOF

  sudo udevadm control --reload
  sudo udevadm trigger --subsystem-match=power_supply
fi
