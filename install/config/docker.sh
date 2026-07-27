# The daemon config, the resolved stub listener, and the no-block-boot drop-in
# are files now — see system/etc/. What's left is what isn't a file.

# Pick up the DNSStubListenerExtra that system-files.sh installed
sudo systemctl restart systemd-resolved

# Start Docker on-demand
sudo systemctl enable docker.socket

# Give this user privileged Docker access
sudo usermod -aG docker ${USER}
