echo "Show battery status notification on right-click of the waybar battery icon"

if ! grep -q 'swarmarchy-battery-status' ~/.config/waybar/config.jsonc; then
  sed -i '/"on-click": "swarmarchy-menu power",/a\    "on-click-right": "notify-send -u low \\"$(swarmarchy-battery-status)\\"",' ~/.config/waybar/config.jsonc
  swarmarchy-restart-waybar
fi
