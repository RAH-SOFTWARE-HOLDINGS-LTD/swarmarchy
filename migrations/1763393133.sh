echo "Link new theme picker config"

mkdir -p ~/.config/elephant/menus
ln -snf $SWARMARCHY_PATH/default/elephant/swarmarchy_themes.lua ~/.config/elephant/menus/swarmarchy_themes.lua
sed -i '/"menus",/d' ~/.config/walker/config.toml
swarmarchy-restart-walker
