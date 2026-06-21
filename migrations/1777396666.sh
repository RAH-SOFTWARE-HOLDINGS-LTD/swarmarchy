echo "Use Swarmarchy UWSM session without graphical.target startup wait"

sudo mkdir -p /usr/local/share/wayland-sessions
sudo cp "$SWARMARCHY_PATH/default/wayland-sessions/swarmarchy.desktop" /usr/local/share/wayland-sessions/swarmarchy.desktop

if [[ -f /etc/sddm.conf.d/autologin.conf ]]; then
  sudo sed -i 's/^Session=hyprland-uwsm$/Session=swarmarchy/' /etc/sddm.conf.d/autologin.conf
fi
