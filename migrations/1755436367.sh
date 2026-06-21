echo "Add minimal starship prompt to terminal"

if swarmarchy-cmd-missing starship; then
  swarmarchy-pkg-add starship
  cp $SWARMARCHY_PATH/config/starship.toml ~/.config/starship.toml
fi
