echo "Add new Swarmarchy Menu icon to Waybar"

mkdir -p ~/.local/share/fonts
cp ~/.local/share/swarmarchy/config/swarmarchy.ttf ~/.local/share/fonts/
fc-cache
