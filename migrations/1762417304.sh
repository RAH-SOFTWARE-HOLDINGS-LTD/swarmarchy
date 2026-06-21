echo "Replace bluetooth GUI with TUI"

swarmarchy-pkg-add bluetui
swarmarchy-pkg-drop blueberry

if ! grep -q "swarmarchy-launch-bluetooth" ~/.config/waybar/config.jsonc; then
  sed -i 's/blueberry/swarmarchy-launch-bluetooth/' ~/.config/waybar/config.jsonc
fi
