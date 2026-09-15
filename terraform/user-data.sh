#!/bin/bash

set -euxo pipefail

apt-get update
apt-get install -y curl jq unzip

curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644

systemctl enable k3s
systemctl start k3s

mkdir -p /home/ubuntu/.kube

cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config

chown -R ubuntu:ubuntu /home/ubuntu/.kube

echo 'export KUBECONFIG=$HOME/.kube/config' >> /home/ubuntu/.bashrc
