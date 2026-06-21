echo "Rename screen recording command"

WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"

if [[ -f $WAYBAR_CONFIG ]] && grep -q 'swarmarchy-capture-screencording' "$WAYBAR_CONFIG"; then
  sed -i 's/swarmarchy-capture-screencording/swarmarchy-capture-screenrecording/g' "$WAYBAR_CONFIG"
  swarmarchy-restart-waybar
fi
