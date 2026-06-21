echo "Rename lock screen command in Hypridle config"

if grep -q 'swarmarchy-lock-screen' ~/.config/hypr/hypridle.conf; then
  sed -i 's/swarmarchy-lock-screen/swarmarchy-system-lock/g' ~/.config/hypr/hypridle.conf
  swarmarchy-restart-hypridle
fi
