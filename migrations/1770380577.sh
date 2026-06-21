echo "Use interactive background selector menu"

mkdir -p ~/.config/elephant/menus
ln -snf $SWARMARCHY_PATH/default/elephant/swarmarchy_background_selector.lua ~/.config/elephant/menus/swarmarchy_background_selector.lua
swarmarchy-restart-walker
