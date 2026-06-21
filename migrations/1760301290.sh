echo "Add the new Flexoki Light theme"

if [[ ! -L ~/.config/swarmarchy/themes/flexoki-light ]]; then
  ln -nfs ~/.local/share/swarmarchy/themes/flexoki-light ~/.config/swarmarchy/themes/
fi
