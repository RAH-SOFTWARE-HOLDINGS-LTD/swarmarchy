echo "Add Catppuccin Latte light theme"

if [[ ! -L $HOME/.config/swarmarchy/themes/catppuccin-latte ]]; then
  ln -snf ~/.local/share/swarmarchy/themes/catppuccin-latte ~/.config/swarmarchy/themes/
fi
