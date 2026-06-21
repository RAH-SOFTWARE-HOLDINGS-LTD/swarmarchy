echo "Add Tmux as an option with themed styling"

swarmarchy-pkg-add tmux

if [[ ! -f ~/.config/tmux/tmux.conf ]]; then
  mkdir -p ~/.config/tmux
  cp $SWARMARCHY_PATH/config/tmux/tmux.conf ~/.config/tmux/tmux.conf
  swarmarchy-theme-refresh
fi
