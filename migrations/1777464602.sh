echo "Update Waybar screen recording command"

WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"

if [[ -f $WAYBAR_CONFIG ]] && grep -q 'swarmarchy-cmd-screenrecord' "$WAYBAR_CONFIG"; then
  sed -i 's/swarmarchy-cmd-screenrecord/swarmarchy-capture-screenrecording/g' "$WAYBAR_CONFIG"
  swarmarchy-restart-waybar
fi
