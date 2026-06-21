echo "Move Swarmarchy Package Repository after Arch core/extra/multilib and remove AUR"

swarmarchy-refresh-pacman
sudo pacman -Syu --noconfirm
