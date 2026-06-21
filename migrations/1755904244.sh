echo "Update fastfetch config with new Swarmarchy logo"

swarmarchy-refresh-config fastfetch/config.jsonc

mkdir -p ~/.config/swarmarchy/branding
cp $SWARMARCHY_PATH/icon.txt ~/.config/swarmarchy/branding/about.txt
