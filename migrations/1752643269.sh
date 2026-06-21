echo "Add new matte black theme"

if [[ ! -L $HOME/.config/swarmarchy/themes/matte-black ]]; then
  ln -snf ~/.local/share/swarmarchy/themes/matte-black ~/.config/swarmarchy/themes/
fi
