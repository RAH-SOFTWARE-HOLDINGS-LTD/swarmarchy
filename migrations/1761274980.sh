echo "Migrate to proper packages for localsend and asdcontrol"

if swarmarchy-pkg-present localsend-bin; then
  swarmarchy-pkg-drop localsend-bin
  swarmarchy-pkg-add localsend
fi

if swarmarchy-pkg-present asdcontrol-git; then
  swarmarchy-pkg-drop asdcontrol-git
  swarmarchy-pkg-add asdcontrol
fi
