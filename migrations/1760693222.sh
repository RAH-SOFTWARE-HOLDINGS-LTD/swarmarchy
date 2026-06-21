echo "Use explicit timezone selector when right-clicking on clock"

sed -i 's/swarmarchy-cmd-tzupdate/swarmarchy-launch-floating-terminal-with-presentation swarmarchy-tz-select/g' ~/.config/waybar/config.jsonc
