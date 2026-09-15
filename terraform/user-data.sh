#!/bin/bash
set -euxo pipefail

apt-get update
apt-get install -y curl jq unzip

# Ensure SSM Agent is running
if command -v snap >/dev/null 2>&1; then
    snap list amazon-ssm-agent >/dev/null 2>&1 || \
        snap install amazon-ssm-agent --classic

    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service || true
    systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service || true
fi

# Install K3s
curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644

systemctl enable k3s
systemctl start k3s

mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

echo 'export KUBECONFIG=$HOME/.kube/config' >> /home/ubuntu/.bashrc
