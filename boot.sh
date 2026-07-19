#!/bin/bash

set -e

# Set install mode to online since boot.sh is used for curl installations
export SWARMARCHY_ONLINE_INSTALL=true

ansi_art='                 ▄▄▄
 ▄█████▄    ▄███████████▄    ▄███████   ▄███████   ▄███████   ▄█   █▄    ▄█   █▄
███   ███  ███   ███   ███  ███   ███  ███   ███  ███   ███  ███   ███  ███   ███
███   ███  ███   ███   ███  ███   ███  ███   ███  ███   █▀   ███   ███  ███   ███
███   ███  ███   ███   ███ ▄███▄▄▄███ ▄███▄▄▄██▀  ███       ▄███▄▄▄███▄ ███▄▄▄███
███   ███  ███   ███   ███ ▀███▀▀▀███ ▀███▀▀▀▀    ███      ▀▀███▀▀▀███  ▀▀▀▀▀▀███
███   ███  ███   ███   ███  ███   ███ ██████████  ███   █▄   ███   ███  ▄██   ███
███   ███  ███   ███   ███  ███   ███  ███   ███  ███   ███  ███   ███  ███   ███
 ▀█████▀    ▀█   ███   █▀   ███   █▀   ███   ███  ███████▀   ███   █▀    ▀█████▀
                                       ███   █▀                                  '

clear
echo -e "\n$ansi_art\n"

# Use custom branch if instructed, otherwise default to master
SWARMARCHY_REF="${SWARMARCHY_REF:-master}"

# Set mirror based on branch.
if [[ $SWARMARCHY_REF == "dev" ]]; then
  export SWARMARCHY_MIRROR=edge
elif [[ $SWARMARCHY_REF == "rc" ]]; then
  export SWARMARCHY_MIRROR=rc
else
  export SWARMARCHY_MIRROR=stable
fi

# Omarchy's mirrors are x86_64-only; on aarch64 keep the existing Arch Linux ARM mirror.
if [[ "$(uname -m)" == "x86_64" ]]; then
  case "$SWARMARCHY_MIRROR" in
    edge) echo 'Server = https://mirror.omarchy.org/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist >/dev/null ;;
    rc)   echo 'Server = https://rc-mirror.omarchy.org/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist >/dev/null ;;
    *)    echo 'Server = https://stable-mirror.omarchy.org/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist >/dev/null ;;
  esac
fi

sudo pacman -Syu --noconfirm --needed git

# Use custom repo if specified, otherwise default to basecamp/omarchy
SWARMARCHY_REPO="${SWARMARCHY_REPO:-basecamp/omarchy}"

echo -e "\nCloning Swarmarchy from: https://github.com/${SWARMARCHY_REPO}.git"
echo -e "\e[32mUsing branch: $SWARMARCHY_REF\e[0m"
rm -rf ~/.local/share/swarmarchy/
git clone --branch "$SWARMARCHY_REF" "https://github.com/${SWARMARCHY_REPO}.git" ~/.local/share/swarmarchy >/dev/null

echo -e "\nInstallation starting..."
source ~/.local/share/swarmarchy/install.sh
