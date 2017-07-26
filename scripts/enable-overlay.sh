#!/bin/bash
sudo tee /etc/modules-load.d/overlay.conf <<-'EOF'
overlay
EOF

sudo mkdir -p /etc/systemd/system/docker.service.d && sudo tee /etc/systemd/system/docker.service.d/override.conf <<- EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --storage-driver=overlay
EOF

echo "Overlay is setup. Please reboot to reload kernel modules."
