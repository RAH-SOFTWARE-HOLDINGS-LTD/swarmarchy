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
