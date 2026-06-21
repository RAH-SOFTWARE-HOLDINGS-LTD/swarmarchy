echo "Add Logout option to system menu"

swarmarchy-refresh-sddm

if [[ -f /etc/sddm.conf.d/autologin.conf ]]; then
  sudo sed -i 's/^Current=.*/Current=swarmarchy/' /etc/sddm.conf.d/autologin.conf
fi
