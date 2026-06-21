echo "Make ethereal available as new theme"

if [[ ! -L ~/.config/swarmarchy/themes/ethereal ]]; then
  rm -rf ~/.config/swarmarchy/themes/ethereal
  ln -nfs ~/.local/share/swarmarchy/themes/ethereal ~/.config/swarmarchy/themes/
fi
