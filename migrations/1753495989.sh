echo "Allow updating of timezone by right-clicking on the clock (or running swarmarchy-cmd-tzupdate)"

if swarmarchy-cmd-missing tzupdate; then
  bash "$SWARMARCHY_PATH/install/config/timezones.sh"
  swarmarchy-refresh-waybar
fi
