echo "Uniquely identify terminal apps with custom app-ids using swarmarchy-launch-tui"

# Replace terminal -e calls with swarmarchy-launch-tui in bindings
sed -i 's/\$terminal -e \([^ ]*\)/swarmarchy-launch-tui \1/g' ~/.config/hypr/bindings.conf

# Update waybar to use swarmarchy-launch-or-focus with swarmarchy-launch-tui for TUI apps
sed -i 's|xdg-terminal-exec btop|swarmarchy-launch-or-focus-tui btop|' ~/.config/waybar/config.jsonc
sed -i 's|xdg-terminal-exec --app-id=com\.swarmarchy\.Wiremix -e wiremix|swarmarchy-launch-or-focus-tui wiremix|' ~/.config/waybar/config.jsonc
