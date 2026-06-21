echo "Install swayOSD to show volume status"

if swarmarchy-cmd-missing swayosd-server; then
  swarmarchy-pkg-add swayosd
  setsid uwsm-app -- swayosd-server &>/dev/null &
fi
