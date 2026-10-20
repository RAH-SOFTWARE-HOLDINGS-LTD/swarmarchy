# Disable multicast dns in resolved. Avahi will provide this for better network printer discovery
sudo mkdir -p /etc/systemd/resolved.conf.d
echo -e "[Resolve]\nMulticastDNS=no" | sudo tee /etc/systemd/resolved.conf.d/10-disable-multicast.conf
chrootable_systemctl_enable avahi-daemon.service

# Enable mDNS resolution for .local domains
sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve files myhostname dns/' /etc/nsswitch.conf

# CUPS is optional (see install/preflight/printing.sh). avahi, the resolved
# MulticastDNS drop-in and the nsswitch mdns entry above stay unconditional:
# they are general .local name resolution on the LAN, not printer-specific.
if [[ ${SWARMARCHY_PRINTING:-0} == 1 ]]; then
  chrootable_systemctl_enable cups.service

  # Enable automatically adding remote printers
  if ! grep -q '^CreateRemotePrinters Yes' /etc/cups/cups-browsed.conf; then
    echo 'CreateRemotePrinters Yes' | sudo tee -a /etc/cups/cups-browsed.conf
  fi

  chrootable_systemctl_enable cups-browsed.service
fi
