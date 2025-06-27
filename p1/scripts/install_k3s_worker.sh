#!/bin/bash

# Update system
sudo apt-get update

# Wait for server to be ready and token to be available
while [ ! -f /vagrant/node-token ]; do
  sleep 5
done

# Install K3s agent
K3S_TOKEN=$(cat /vagrant/node-token)
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 K3S_TOKEN=$K3S_TOKEN sh -
