echo "Replace volume control GUI with a TUI"

if swarmarchy-cmd-missing wiremix; then
  swarmarchy-pkg-add wiremix
  swarmarchy-pkg-drop pavucontrol
  swarmarchy-refresh-applications
  swarmarchy-refresh-waybar
fi
