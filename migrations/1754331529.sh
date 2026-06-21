echo "Update Waybar for new Swarmarchy menu"

if ! grep -q "" ~/.config/waybar/config.jsonc; then
  swarmarchy-refresh-waybar
fi
