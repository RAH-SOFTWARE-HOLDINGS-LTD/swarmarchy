# Small system-level tweaks that run after the packages and the system/ tree are in
# place. Each section is only a few lines, so they live together instead of in a
# file apiece. Order matters in two places: gpg needs system-files.sh to have
# installed dirmngr.conf first, and the locate database goes last so it sees
# everything installed above.

# ─── GnuPG ────────────────────────────────────────────────────────────────────
# The keyserver list is a file now — see system/etc/gnupg/dirmngr.conf.
# dirmngr reads its config at startup, so it has to be bounced to pick it up.
sudo gpgconf --kill dirmngr || true
sudo gpgconf --launch dirmngr || true

# ─── powerprofilesctl ─────────────────────────────────────────────────────────
# Ensure we use system python3 and not mise's python3
sudo sed -i '/env python3/ c\#!/bin/python3' /usr/bin/powerprofilesctl

# ─── Podman ───────────────────────────────────────────────────────────────────
# Rootless containers map container UIDs onto a subordinate range owned by the
# user. useradd normally allocates one; ensure it for users created without it.
# (Short image names resolve via system/etc/containers/registries.conf.d, and the
# user-level podman.socket is enabled in first-run/session.sh.)
if ! grep -q "^${USER}:" /etc/subuid; then
  sudo usermod --add-subuids 100000-165535 "$USER"
fi
if ! grep -q "^${USER}:" /etc/subgid; then
  sudo usermod --add-subgids 100000-165535 "$USER"
fi

# ─── Kernel modules cleanup ───────────────────────────────────────────────────
chrootable_systemctl_enable linux-modules-cleanup.service

# ─── locate database ──────────────────────────────────────────────────────────
# Update localdb so that locate will find everything installed
sudo updatedb
