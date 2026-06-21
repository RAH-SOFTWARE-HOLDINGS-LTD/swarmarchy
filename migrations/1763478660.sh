echo "Configure XDPH config for screensharing to remember token selection"

cp $SWARMARCHY_PATH/config/hypr/xdph.conf ~/.config/hypr/
systemctl --user restart xdg-desktop-portal-hyprland
