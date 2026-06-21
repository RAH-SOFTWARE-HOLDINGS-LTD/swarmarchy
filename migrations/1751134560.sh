echo "Add UWSM env"

export SWARMARCHY_PATH="$HOME/.local/share/swarmarchy"
export PATH="$SWARMARCHY_PATH/bin:$PATH"

mkdir -p "$HOME/.config/uwsm/"
cat <<EOF | tee "$HOME/.config/uwsm/env"
export SWARMARCHY_PATH=$HOME/.local/share/swarmarchy
export PATH=$SWARMARCHY_PATH/bin/:$PATH
EOF

# Ensure we have the latest repos and are ready to pull
swarmarchy-update-keyring
swarmarchy-refresh-pacman
sudo systemctl restart systemd-timesyncd
sudo pacman -Sy # Normally not advisable, but we'll do a full -Syu before finishing

mkdir -p ~/.local/state/swarmarchy/migrations
touch ~/.local/state/swarmarchy/migrations/1751134560.sh

# Remove old AUR packages to prevent a super lengthy build on old Swarmarchy installs
swarmarchy-pkg-drop zoom qt5-remoteobjects wf-recorder wl-screenrec

# Get rid of old AUR packages
bash $SWARMARCHY_PATH/migrations/1756060611.sh
touch ~/.local/state/swarmarchy/migrations/1756060611.sh

bash swarmarchy-update-perform
