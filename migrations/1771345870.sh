echo "Switch lmstudio -> lmstudio-bin"

if pacman -Q lmstudio &>/dev/null; then
  swarmarchy-pkg-drop lmstudio
  swarmarchy-pkg-add lmstudio-bin
fi
