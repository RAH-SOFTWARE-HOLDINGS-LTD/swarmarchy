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
