# Copy over Swarmarchy configs
mkdir -p ~/.config
cp -R "$SWARMARCHY_PATH"/config/* ~/.config/

# Use default bashrc from Swarmarchy
cp "$SWARMARCHY_PATH"/default/bashrc ~/.bashrc
