# (Yaru icon theme dropped on aarch64 — Nautilus uses Adwaita's action icons directly, no patch needed.)

# Setup user theme folder
mkdir -p ~/.config/swarmarchy/themes

# Chromium policy directory for theme
sudo mkdir -p /etc/chromium/policies/managed
sudo chmod a+rw /etc/chromium/policies/managed

# Set initial theme
swarmarchy-theme-set "Tokyo Night"
rm -rf ~/.config/chromium/SingletonLock # otherwise archiso will own the chromium singleton

# Set specific app links for current theme
mkdir -p ~/.config/btop/themes
ln -snf ~/.config/swarmarchy/current/theme/btop.theme ~/.config/btop/themes/current.theme

mkdir -p ~/.config/mako
ln -snf ~/.config/swarmarchy/current/theme/mako.ini ~/.config/mako/config

# Default Chromium to follow system appearance ("device") instead of dark
echo '{"browser":{"theme":{"color_scheme":0,"color_scheme2":0}}}' | sudo tee /usr/lib/chromium/initial_preferences >/dev/null
