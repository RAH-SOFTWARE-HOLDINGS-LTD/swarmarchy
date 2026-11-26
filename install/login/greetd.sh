# Set up greetd + gtkgreet as the login manager, launching Sway.
# (Replaces SDDM, which was removed. greetd is a minimal, Wayland-friendly greeter.)

swarmarchy-pkg-add greetd greetd-gtkgreet

# Make the swarmarchy session discoverable (for greeters that list sessions)
sudo mkdir -p /usr/share/wayland-sessions
# Symlink: /usr/share/swarmarchy/default persists, $SWARMARCHY_PATH does not.
sudo ln -sfn /usr/share/swarmarchy/default/wayland-sessions/swarmarchy.desktop \
  /usr/share/wayland-sessions/swarmarchy.desktop

# Session wrapper. greetd runs the session through a non-interactive login shell
# and sway is not a systemd unit, so ~/.config/environment.d/*.conf would never
# reach the compositor -- leaving swarmarchy-* off PATH (every keybind a silent
# no-op) and WLR_RENDERER/XDG_CURRENT_DESKTOP unset. Installed system-wide so it
# resolves by name from the greeter's PATH, and is user-agnostic at runtime.
# Symlink, not a copy. install/config/system-files.sh has already put the real
# file at /usr/lib/swarmarchy/bin/swarmarchy-session (config/ runs before login/),
# and that path persists -- unlike $SWARMARCHY_PATH, which post-install deletes.
# A copy here would silently go stale every time the repo is redeployed, and the
# stale one is the copy greetd actually runs, because /usr/lib/swarmarchy/bin is
# not on anyone's PATH while /usr/local/bin is.
sudo ln -sfn /usr/lib/swarmarchy/bin/swarmarchy-session /usr/local/bin/swarmarchy-session

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
sudo install -m 0644 "$SWARMARCHY_PATH/default/greetd/gtkgreet.css" \
  /etc/greetd/gtkgreet.css

# The greeter's sway and gtkgreet write their logs to stdout/stderr, which greetd leaves
# on VT1 -- so output notes, GTK warnings and Mesa's "shader cache (Permission denied)"
# printed over the boot screen before the login prompt. systemd-cat sends them to the
# journal instead (journalctl -t greeter).
cat <<EOF | sudo tee /etc/greetd/config.toml >/dev/null
[terminal]
vt = 1

[default_session]
command = "systemd-cat -t greeter sway --config /etc/greetd/sway-greeter.conf"
user = "greeter"
EOF

# The greeter runs a real compositor, so it needs input devices as well as DRM.
# logind normally delegates both to the session on the seat; the group membership
# is a cheap hedge against a lockout if it does not.
sudo usermod -aG input greeter

# Give the greeter a home it can write. greetd's sysusers entry makes it /, so Mesa in
# the greeter's sway could not create ~/.cache ("shader cache (Permission denied)") and
# rebuilt every shader at each boot. XDG_CACHE_HOME does not help: Arch's sway carries
# cap_sys_nice, which makes it a secure-exec process, and Mesa then ignores the
# environment and uses the passwd home. systemd-sysusers never changes an existing
# account, so the new home sticks. usermod refuses while the greeter is running, which
# only happens at the login screen -- never while an install or redeploy runs.
sudo install -d -m 0750 -o greeter -g greeter /var/lib/greeter
if [[ $(getent passwd greeter | cut -d: -f6) != "/var/lib/greeter" ]]; then
  sudo usermod -d /var/lib/greeter greeter
fi

# ─── oo7 keyring ────────────────────────────────────────────────────────────
#
# swarmarchy-base.packages ships oo7 as the Secret Service provider. It must be
# unlocked for the whole session: Chromium-based browsers block waiting for their
# cookie-encryption key, and every page navigation is cancelled before it reaches
# DNS while curl and Firefox work fine -- which looks like a network fault.
#
# Default: no real keyring password. oo7 unlocks the keyring on its own at startup
# with a fixed value (config/systemd/user/oo7-daemon.service.d/no-password.conf),
# so the login below does not touch the keyring and nothing waits for it.
#
# `swarmarchy toggle keyring-password on` switches to the login password instead:
# it installs default/oo7/pam-greetd-protected (pam_oo7 hands the login password to
# the daemon) and default/oo7/wait-for-pam-socket.conf. The helper below is only
# used in that mode; it is symlinked so the path stays valid after a redeploy.
sudo mkdir -p /usr/local/lib
sudo ln -sfn /usr/share/swarmarchy/default/oo7/oo7-wait-pam-socket \
  /usr/local/lib/oo7-wait-pam-socket

sudo mkdir -p /etc/pam.d
[[ -f /etc/pam.d/greetd && ! -f /etc/pam.d/greetd.bak-pre-oo7 ]] &&
  sudo cp /etc/pam.d/greetd /etc/pam.d/greetd.bak-pre-oo7
sudo install -m 0644 "$SWARMARCHY_PATH/default/oo7/pam-greetd" /etc/pam.d/greetd

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl enable greetd.service
