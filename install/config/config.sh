# Copy over Swarmarchy configs
mkdir -p ~/.config
cp -R ~/.local/share/swarmarchy/config/* ~/.config/

# Use default bashrc from Swarmarchy
cp ~/.local/share/swarmarchy/default/bashrc ~/.bashrc
