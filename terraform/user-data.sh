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

# -----------------------------
# Install K3s
# -----------------------------
curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644

systemctl enable k3s
systemctl start k3s

# Wait for Kubernetes
until /usr/local/bin/k3s kubectl get nodes >/dev/null 2>&1; do
    echo "Waiting for K3s..."
    sleep 5
done

# -----------------------------
# Install Argo CD
# -----------------------------
/usr/local/bin/k3s kubectl create namespace argocd

/usr/local/bin/k3s kubectl apply \
    -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD
/usr/local/bin/k3s kubectl rollout status \
    deployment/argocd-server \
    -n argocd \
    --timeout=300s
