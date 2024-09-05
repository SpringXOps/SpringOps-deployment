#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Update package list and install prerequisites
echo "Updating package list and installing prerequisites..."
apt-get update
apt-get install -y curl

# Install K3s
echo "Installing K3s..."
curl -sfL https://get.k3s.io | sh -

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
until kubectl get nodes | grep -q "Ready"; do
    sleep 5
done

# Set up for root user
echo "Setting up K3s for root user..."
mkdir -p /root/.kube
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
chmod 600 /root/.kube/config

# Set up for user 'sen'
echo "Setting up K3s for user 'sen'..."
mkdir -p /home/sen/.kube
cp /etc/rancher/k3s/k3s.yaml /home/sen/.kube/config
sed -i 's/127.0.0.1/'"$(hostname -I | awk '{print $1}')"'/g' /home/sen/.kube/config
chown sen:sen /home/sen/.kube/config
chmod 600 /home/sen/.kube/config

# Add user 'sen' to the correct group to use kubectl
usermod -aG sudo sen

# Set up kubectl autocompletion for both users
echo "Setting up kubectl autocompletion..."
kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
echo 'source <(kubectl completion bash)' >> /root/.bashrc
echo 'source <(kubectl completion bash)' >> /home/sen/.bashrc

echo "K3s installation and setup complete!"
echo "Please log out and log back in for group changes to take effect."
echo "You can now use 'kubectl' to interact with your K3s cluster."