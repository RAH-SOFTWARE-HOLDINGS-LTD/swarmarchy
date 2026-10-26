# Put the repo's output onto the system: first the deployed /usr + /etc/skel trees
# (section 1), then the system/ tree on top of /, verbatim (section 2).

# ─── 1. Deploy ────────────────────────────────────────────────────────────────
# Install the repo's OUTPUT into the system tree, then stop depending on the repo.
#
# swarmarchy-dev-deploy stages exactly what a package would ship:
#   /usr/lib/swarmarchy/bin        the swarmarchy-* commands
#   /usr/share/swarmarchy/default  the shipped defaults that ~/.config includes
#   /usr/share/swarmarchy/themes   themes + applications
#   /etc/skel/.config              the factory seed for new users
#   /                              the system/ tree, verbatim
#
# Without this an installed machine has no `swarmarchy` command at all, and every
# ~/.config/sway/config `include /usr/share/swarmarchy/default/sway/...` dangles,
# so Sway comes up with no keybindings and no autostart.
#
# This is also what makes the source tree disposable: once deployed, nothing on the
# running system references SWARMARCHY_PATH, and post-install/cleanup-source.sh
# deletes it.
sudo "$SWARMARCHY_PATH/bin/swarmarchy-dev-deploy"

# ─── 2. system/ tree ──────────────────────────────────────────────────────────
# Place the system/ tree, which mirrors the target filesystem verbatim
# (system/etc/foo -> /etc/foo). Everything here used to be a heredoc inside an
# install script; as files they are diffable, idempotent, and deployable to an
# already-installed machine by swarmarchy-dev-deploy.
#
# No --delete: this tree interleaves with directories owned by other packages,
# so it may only add and overwrite its own files.
# --chown=root:root is load-bearing: -a implies -o/-g, and this repo is owned by
# the user (uid 1000). Without it, rsync stamps that ownership onto /etc, and sudo
# refuses to read a /etc/sudoers.d it does not see as root-owned -- which locks the
# user out of sudo entirely ("ralphie02 is not in the sudoers file").
sudo rsync -a --chown=root:root "$SWARMARCHY_PATH/system/" /

# sudoers ignores any file that is group- or world-writable.
sudo chmod 0440 /etc/sudoers.d/swarmarchy-tzupdate
sudo visudo -c >/dev/null

sudo systemctl daemon-reload
sudo sysctl --system >/dev/null 2>&1 || true
