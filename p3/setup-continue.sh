#!/bin/bash

echo "Continuing setup with proper Docker permissions..."

# Verify Docker access
if ! docker ps > /dev/null 2>&1; then
    echo "ERROR: Docker permission issue still exists"
    echo "Please run: sudo usermod -aG docker $USER"
    echo "Then logout and login again, or run: newgrp docker"
    exit 1
fi

echo "Docker access verified ✓"

# Install K3d
echo "Installing K3d..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Clean up any existing cluster
echo "Cleaning up any existing cluster..."
k3d cluster delete iot-cluster 2>/dev/null || true

# Create K3d cluster
echo "Creating K3d cluster..."
k3d cluster create iot-cluster \
  --port 8080:80@loadbalancer \
  --port 8443:443@loadbalancer \
  --wait

# Verify cluster is running
echo "Verifying cluster..."
kubectl cluster-info

# Install ArgoCD
echo "Installing ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Create dev namespace
echo "Creating dev namespace..."
kubectl create namespace dev

# Wait for ArgoCD to be ready
echo "Waiting for ArgoCD to be ready (this may take a few minutes)..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Get ArgoCD admin password
echo "Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin password: $ARGOCD_PASSWORD"

# Save password to file for reference
echo $ARGOCD_PASSWORD > argocd-password.txt
echo "Password saved to argocd-password.txt"

# Apply application configuration (if exists)
if [ -f "/vagrant/confs/application.yaml" ]; then
    echo "Applying application configuration..."
    kubectl apply -f /vagrant/confs/application.yaml
elif [ -f "confs/application.yaml" ]; then
    echo "Applying application configuration..."
    kubectl apply -f confs/application.yaml
else
    echo "No application configuration found. You can apply it later with:"
    echo "kubectl apply -f confs/application.yaml"
fi

echo ""
echo "Setup complete! ✓"
echo ""
echo "ArgoCD Details:"
echo "- Username: admin"
echo "- Password: $ARGOCD_PASSWORD"
echo "- URL: https://localhost:8080 (after port-forward)"
echo ""
echo "To access ArgoCD:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "To check cluster status:"
echo "kubectl get nodes"
echo "kubectl get pods -A"
