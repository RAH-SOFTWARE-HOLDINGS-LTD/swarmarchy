if swarmarchy-battery-present; then
  cat <<EOF | sudo tee "/etc/udev/rules.d/99-power-profile.rules"
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="/usr/bin/systemd-run --no-block --collect --unit=swarmarchy-power-profile --property=After=power-profiles-daemon.service /usr/lib/swarmarchy/bin/swarmarchy-powerprofiles-set"
SUBSYSTEM=="power_supply", ATTR{type}=="USB", RUN+="/usr/bin/systemd-run --no-block --collect --unit=swarmarchy-power-profile --property=After=power-profiles-daemon.service /usr/lib/swarmarchy/bin/swarmarchy-powerprofiles-set"
EOF


  # Passwordless governor changes so the Sway autostart and menu paths work
  # without a password prompt. Scoped to one root-owned helper that can only
  # write a kernel-offered governor name.
  echo "$USER ALL=(ALL) NOPASSWD: /usr/lib/swarmarchy/bin/swarmarchy-powerprofiles-governor" |
    sudo tee /etc/sudoers.d/swarmarchy-powerprofiles >/dev/null
  sudo chmod 440 /etc/sudoers.d/swarmarchy-powerprofiles

  sudo systemctl enable power-profiles-daemon

  sudo udevadm control --reload 2>/dev/null
  sudo udevadm trigger --subsystem-match=power_supply 2>/dev/null
fi
