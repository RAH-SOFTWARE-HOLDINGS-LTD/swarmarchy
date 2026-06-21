echo "Make hackerman available as new theme"

if [[ ! -L ~/.config/swarmarchy/themes/hackerman ]]; then
  rm -rf ~/.config/swarmarchy/themes/hackerman
  ln -nfs ~/.local/share/swarmarchy/themes/hackerman ~/.config/swarmarchy/themes/
fi
