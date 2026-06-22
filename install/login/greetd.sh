# Set up greetd + tuigreet as the login manager, launching Sway.
# (Replaces SDDM, which was removed. greetd is a minimal, Wayland-friendly greeter.)

swarmarchy-pkg-add greetd greetd-tuigreet

# Make the swarmarchy session discoverable (for greeters that list sessions)
sudo mkdir -p /usr/share/wayland-sessions
sudo cp "$SWARMARCHY_PATH/default/wayland-sessions/swarmarchy.desktop" \
  /usr/share/wayland-sessions/swarmarchy.desktop

# greetd config: tuigreet greeter that launches Sway directly.
sudo mkdir -p /etc/greetd
cat <<EOF | sudo tee /etc/greetd/config.toml >/dev/null
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --asterisks --cmd sway"
user = "greeter"
EOF

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl enable greetd.service
