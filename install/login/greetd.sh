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

# ─── oo7 keyring unlock at login ────────────────────────────────────────────
#
# swarmarchy-base.packages ships oo7 as the Secret Service provider, but nothing
# unlocked it, so org.freedesktop.secrets stayed locked for the whole session.
# Chromium-based browsers block waiting for their cookie-encryption key and every
# page navigation is cancelled before it reaches DNS, while the browser's own
# background traffic and curl work fine -- which makes it look like a network
# fault for a long time. Firefox is unaffected; it does not use the keyring.
#
# The race: pam_oo7 (session phase) makes ONE attempt to connect to
# /run/user/<uid>/oo7-pam.sock. oo7-daemon.service is started by the user manager
# in parallel with login and creates that socket ~100ms later, and PAM does not
# wait for user units. So the stashed password is dropped and the keyring stays
# locked.
#
# Do NOT use `pam_oo7.so auto_start` to work around this: it hard-codes
# /usr/bin/oo7-daemon while Arch installs the binary at /usr/lib/oo7-daemon, and
# symlinking the two makes auto_start spawn a second daemon outside systemd that
# races the enabled unit.
# Symlink for the same reason: /usr/share/swarmarchy/default persists, the source
# tree does not, and PAM needs an absolute path that stays correct after a redeploy.
sudo mkdir -p /usr/local/lib
sudo ln -sfn /usr/share/swarmarchy/default/oo7/oo7-wait-pam-socket \
  /usr/local/lib/oo7-wait-pam-socket

# PAM stack. Every added line is optional or default=ignore, so a keyring failure
# can never block a login. The success=N jump counts depend on the exact line
# order below -- do not insert lines between them.
sudo mkdir -p /etc/pam.d
[[ -f /etc/pam.d/greetd && ! -f /etc/pam.d/greetd.bak-pre-oo7 ]] &&
  sudo cp /etc/pam.d/greetd /etc/pam.d/greetd.bak-pre-oo7
cat <<'PAMEOF' | sudo tee /etc/pam.d/greetd >/dev/null
#%PAM-1.0

auth       required     pam_securetty.so
auth       requisite    pam_nologin.so
auth       include      system-local-login
# Stash the login password. Must come AFTER the real auth, or PAM_AUTHTOK is unset.
auth       optional     pam_oo7.so

account    include      system-local-login

password   include      system-local-login
# Keep the keyring password in step when the login password changes.
password   optional     pam_oo7.so

session    include      system-local-login
# Wait for oo7's PAM socket, then up to 3 unlock attempts. After each attempt the
# check exits 0 if the keyring is unlocked (skipping the rest), else waits and retries.
session    optional                       pam_exec.so quiet /usr/local/lib/oo7-wait-pam-socket
session    optional                       pam_oo7.so
session    [success=3 default=ignore]     pam_exec.so quiet /usr/local/lib/oo7-wait-pam-socket check 2
session    optional                       pam_oo7.so
session    [success=1 default=ignore]     pam_exec.so quiet /usr/local/lib/oo7-wait-pam-socket check 3
session    optional                       pam_oo7.so
session    optional                       pam_permit.so
PAMEOF

# Don't use chrootable here as --now will cause issues for manual installs
sudo systemctl enable greetd.service
