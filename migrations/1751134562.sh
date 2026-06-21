echo "Ensure all indexes and packages are up to date"

swarmarchy-update-keyring
swarmarchy-refresh-pacman
sudo pacman -Syu --noconfirm
