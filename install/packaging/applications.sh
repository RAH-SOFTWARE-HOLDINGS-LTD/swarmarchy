# Bundled icons, web apps and TUI launchers.
# Kept as one file because swarmarchy-refresh-applications re-runs exactly this
# set after an update, and the TUI launchers use the icons copied first.

# ─── Icons ────────────────────────────────────────────────────────────────────
# Copy all bundled icons to the applications/icons directory
ICON_DIR="$HOME/.local/share/applications/icons"
mkdir -p "$ICON_DIR"
cp "$SWARMARCHY_PATH"/applications/icons/*.png "$ICON_DIR/"

# ─── Web apps ─────────────────────────────────────────────────────────────────
swarmarchy-webapp-install "GitHub" https://github.com/ GitHub.png
swarmarchy-webapp-install "Zoom" https://app.zoom.us/wc/home Zoom.png "swarmarchy-webapp-handler-zoom %u" "x-scheme-handler/zoommtg;x-scheme-handler/zoomus"

# ─── TUIs ─────────────────────────────────────────────────────────────────────
swarmarchy-tui-install "Disk Usage" "bash -c 'dust -r; read -n 1 -s'" float "$ICON_DIR/Disk Usage.png"
