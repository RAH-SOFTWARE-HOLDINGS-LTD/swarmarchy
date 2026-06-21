echo "Install Impala as new wifi selection TUI"

if swarmarchy-cmd-missing impala; then
  swarmarchy-pkg-add impala
  swarmarchy-refresh-waybar
fi
