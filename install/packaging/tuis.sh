ICON_DIR="$HOME/.local/share/applications/icons"

swarmarchy-tui-install "Disk Usage" "bash -c 'dust -r; read -n 1 -s'" float "$ICON_DIR/Disk Usage.png"
swarmarchy-tui-install "Docker" "lazydocker" tile "$ICON_DIR/Docker.png"
