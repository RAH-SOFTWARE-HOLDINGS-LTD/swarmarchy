echo "Add sample low battery notification hook"

mkdir -p ~/.config/swarmarchy/hooks/battery-low.d

if [[ ! -f ~/.config/swarmarchy/hooks/battery-low.d/play-warning-sound.sample ]]; then
  cp "$SWARMARCHY_PATH/config/swarmarchy/hooks/battery-low.d/play-warning-sound.sample" ~/.config/swarmarchy/hooks/battery-low.d/play-warning-sound.sample
fi
