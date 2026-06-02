#!/bin/bash
set -euo pipefail

# ── Install Docker + Docker Compose ──────────────────────────────────────────
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release git

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Enable docker on boot
systemctl enable --now docker

# ── Create app directory ─────────────────────────────────────────────────────
mkdir -p /opt/${project_name}
chown ubuntu:ubuntu /opt/${project_name}

echo "Bootstrap complete. Docker $(docker --version) installed."
