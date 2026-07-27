#!/bin/bash

# Ensure Walker service is started automatically on boot
mkdir -p ~/.config/autostart/
cp $SWARMARCHY_PATH/default/walker/walker.desktop ~/.config/autostart/

# And is restarted if it crashes or is killed
mkdir -p ~/.config/systemd/user/app-walker@autostart.service.d/
cp $SWARMARCHY_PATH/default/walker/restart.conf ~/.config/systemd/user/app-walker@autostart.service.d/restart.conf

# The pacman hook that restarts walker after updates is a file now:
# system/etc/pacman.d/hooks/walker-restart.hook

# Link the visual theme menu config
mkdir -p ~/.config/elephant/menus
ln -snf $SWARMARCHY_PATH/default/elephant/swarmarchy_themes.lua ~/.config/elephant/menus/swarmarchy_themes.lua
ln -snf $SWARMARCHY_PATH/default/elephant/swarmarchy_background_selector.lua ~/.config/elephant/menus/swarmarchy_background_selector.lua
ln -snf $SWARMARCHY_PATH/default/elephant/swarmarchy_unlocks.lua ~/.config/elephant/menus/swarmarchy_unlocks.lua
