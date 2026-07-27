# The keyserver list is a file now — see system/etc/gnupg/dirmngr.conf.
# dirmngr reads its config at startup, so it has to be bounced to pick it up.
sudo gpgconf --kill dirmngr || true
sudo gpgconf --launch dirmngr || true
