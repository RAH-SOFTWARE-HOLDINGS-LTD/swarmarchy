stop_install_log

# tte (terminaltexteffects) renders the animated logo. It is not packaged for
# aarch64 and is not in any package list, so fall back to plain output rather
# than ending a successful install on "tte: command not found".
has_tte() { command -v tte &>/dev/null; }

echo_in_style() {
  if has_tte; then
    echo "$1" | tte --canvas-width 0 --anchor-text c --frame-rate 640 print
  else
    echo "$1"
  fi
}

clear
echo
if has_tte; then
  tte -i "$SWARMARCHY_PATH/logo.txt" --canvas-width 0 --anchor-text c --frame-rate 920 laseretch
else
  cat "$SWARMARCHY_PATH/logo.txt"
fi
echo

# Display installation time if available
if [[ -f $SWARMARCHY_INSTALL_LOG_FILE ]] && grep -q "Total:" "$SWARMARCHY_INSTALL_LOG_FILE" 2>/dev/null; then
  echo
  TOTAL_TIME=$(tail -n 20 "$SWARMARCHY_INSTALL_LOG_FILE" | grep "^Total:" | sed 's/^Total:[[:space:]]*//')
  if [[ -n $TOTAL_TIME ]]; then
    echo_in_style "Installed in $TOTAL_TIME"
  fi
else
  echo_in_style "Finished installing"
fi

if sudo test -f /etc/sudoers.d/99-swarmarchy-installer; then
  sudo rm -f /etc/sudoers.d/99-swarmarchy-installer &>/dev/null
fi

# Exit gracefully if user chooses not to reboot
if gum confirm --padding "0 0 0 $((PADDING_LEFT + 32))" --show-help=false --default --affirmative "Reboot Now" --negative "" ""; then
  # Clear screen to hide any shutdown messages
  clear

  if [[ -n ${SWARMARCHY_CHROOT_INSTALL:-} ]]; then
    touch /var/tmp/swarmarchy-install-completed
    exit 0
  else
    sudo reboot 2>/dev/null
  fi
fi
