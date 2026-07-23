# Set up greetd + tuigreet as the login manager, launching Sway.
# (Replaces SDDM, which was removed. greetd is a minimal, Wayland-friendly greeter.)

swarmarchy-pkg-add greetd greetd-tuigreet

# Make the swarmarchy session discoverable (for greeters that list sessions)
sudo mkdir -p /usr/share/wayland-sessions
sudo cp "$SWARMARCHY_PATH/default/wayland-sessions/swarmarchy.desktop" \
  /usr/share/wayland-sessions/swarmarchy.desktop

# Session wrapper. greetd runs the session through a non-interactive login shell
# and sway is not a systemd unit, so ~/.config/environment.d/*.conf would never
# reach the compositor -- leaving swarmarchy-* off PATH (every keybind a silent
# no-op) and WLR_RENDERER/XDG_CURRENT_DESKTOP unset. Installed system-wide so it
# resolves by name from the greeter's PATH, and is user-agnostic at runtime.
sudo install -m 0755 "$SWARMARCHY_PATH/bin/swarmarchy-session" /usr/local/bin/swarmarchy-session

# greetd config: tuigreet greeter that launches Sway via the session wrapper.
sudo mkdir -p /etc/greetd
cat <<EOF | sudo tee /etc/greetd/config.toml >/dev/null
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --asterisks --cmd swarmarchy-session"
user = "greeter"
EOF

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl enable greetd.service
