echo "Add sample post-boot hook"

mkdir -p ~/.config/swarmarchy/hooks/post-boot.d

if [[ ! -f ~/.config/swarmarchy/hooks/post-boot.d/weather.sample ]]; then
  cp "$SWARMARCHY_PATH/config/swarmarchy/hooks/post-boot.d/weather.sample" ~/.config/swarmarchy/hooks/post-boot.d/weather.sample
fi
