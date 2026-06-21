echo "Add .config/brave-flags.conf by default to ensure Brave runs under Wayland"

if [[ ! -f ~/.config/brave-flags.conf ]]; then
  cp $SWARMARCHY_PATH/config/brave-flags.conf ~/.config/
fi
