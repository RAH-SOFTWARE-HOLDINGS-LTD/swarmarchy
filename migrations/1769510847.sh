echo "Switch back to mainline chromium now that it supports full live theming"

if swarmarchy-pkg-present swarmarchy-chromium; then
  if gum confirm "Ready to switch to mainstream chromium? (Will close Chromium + reset settings)"; then
    pkill -x chromium
    swarmarchy-pkg-drop swarmarchy-chromium
    swarmarchy-pkg-add chromium
    swarmarchy-theme-set-browser
  fi
fi
