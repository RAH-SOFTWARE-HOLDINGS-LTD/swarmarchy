echo "Replace wofi with walker as the default launcher"

if swarmarchy-cmd-missing walker; then
  swarmarchy-pkg-add walker-bin libqalculate

  swarmarchy-pkg-drop wofi
  rm -rf ~/.config/wofi

  mkdir -p ~/.config/walker
  cp -r ~/.local/share/swarmarchy/config/walker/* ~/.config/walker/
fi
