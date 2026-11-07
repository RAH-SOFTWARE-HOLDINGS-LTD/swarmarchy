# Set up greetd + gtkgreet as the login manager, launching Sway.
# (Replaces SDDM, which was removed. greetd is a minimal, Wayland-friendly greeter.)

swarmarchy-pkg-add greetd greetd-gtkgreet

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

# greetd config: gtkgreet inside a minimal Sway, launching the session wrapper.
#
# Was tuigreet, which draws on the kernel framebuffer console. Every output scans
# out one shared fb0 buffer cropped to its own size, so there is a single centre
# position for differently sized panels and the prompt cannot be centred on external
# monitors. gtkgreet runs as a Wayland layer-shell surface inside a compositor that
# sees real outputs, so it centres on each one.
sudo mkdir -p /etc/greetd
sudo install -m 0644 "$SWARMARCHY_PATH/default/greetd/sway-greeter.conf" \
  /etc/greetd/sway-greeter.conf

cat <<EOF | sudo tee /etc/greetd/config.toml >/dev/null
[terminal]
vt = 1

[default_session]
command = "sway --config /etc/greetd/sway-greeter.conf"
user = "greeter"
EOF

# The greeter runs a real compositor, so it needs input devices as well as DRM.
# logind normally delegates both to the session on the seat; the group membership
# is a cheap hedge against a lockout if it does not.
sudo usermod -aG input greeter

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl enable greetd.service
