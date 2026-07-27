# Place the system/ tree, which mirrors the target filesystem verbatim
# (system/etc/foo -> /etc/foo). Everything here used to be a heredoc inside an
# install script; as files they are diffable, idempotent, and deployable to an
# already-installed machine by swarmarchy-dev-deploy.
#
# No --delete: this tree interleaves with directories owned by other packages,
# so it may only add and overwrite its own files.
sudo rsync -a "$SWARMARCHY_PATH/system/" /

# sudoers ignores any file that is group- or world-writable.
sudo chmod 0440 /etc/sudoers.d/swarmarchy-tzupdate
sudo visudo -c >/dev/null

sudo systemctl daemon-reload
sudo sysctl --system >/dev/null 2>&1 || true
