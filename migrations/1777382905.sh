echo "Use interactive unlock (Plymouth) selector menu"

mkdir -p ~/.config/elephant/menus
ln -snf $SWARMARCHY_PATH/default/elephant/swarmarchy_unlocks.lua ~/.config/elephant/menus/swarmarchy_unlocks.lua
swarmarchy-restart-walker
