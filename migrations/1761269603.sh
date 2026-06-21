echo "Add right-click terminal action to waybar swarmarchy menu icon"

WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"

if [[ -f $WAYBAR_CONFIG ]] && ! grep -A5 '"custom/swarmarchy"' "$WAYBAR_CONFIG" | grep -q '"on-click-right"'; then
  sed -i '/"on-click": "swarmarchy-menu",/a\    "on-click-right": "swarmarchy-launch-terminal",' "$WAYBAR_CONFIG"
fi
