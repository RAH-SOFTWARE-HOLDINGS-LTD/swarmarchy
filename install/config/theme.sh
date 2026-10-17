# (Yaru icon theme dropped on aarch64 — Nautilus uses Adwaita's action icons directly, no patch needed.)

# Setup user theme folder
mkdir -p ~/.config/swarmarchy/themes

# Brave policy directory for theme. swarmarchy-theme-set-browser writes color.json here,
# but skips any policy dir that doesn't exist — so without this, Brave is never themed.
sudo mkdir -p /etc/brave/policies/managed
sudo chmod a+rw /etc/brave/policies/managed

# Set initial theme
swarmarchy-theme-set "Tokyo Night"

# Set specific app links for current theme
mkdir -p ~/.config/btop/themes
ln -snf ~/.config/swarmarchy/current/theme/btop.theme ~/.config/btop/themes/current.theme

mkdir -p ~/.config/mako
ln -snf ~/.config/swarmarchy/current/theme/mako.ini ~/.config/mako/config
