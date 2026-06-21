echo "Add the new ristretto theme as an option"

if [[ ! -L ~/.config/swarmarchy/themes/ristretto ]]; then
  ln -nfs ~/.local/share/swarmarchy/themes/ristretto ~/.config/swarmarchy/themes/
fi
