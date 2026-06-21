echo "Enable Bluetooth A2DP auto-connect in WirePlumber"

destination=~/.config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf

mkdir -p ~/.config/wireplumber/wireplumber.conf.d/

if [[ ! -f "$destination" ]]; then
  cp "$SWARMARCHY_PATH/default/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf" \
    "$destination"
fi

swarmarchy-state set reboot-required
