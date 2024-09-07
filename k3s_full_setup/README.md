# Comprehensive K3s, Helm, ArgoCD, and Dashboard Setup Guide

This guide provides instructions for setting up K3s (with an option for High Availability), Helm, ArgoCD, and the Kubernetes Dashboard. It includes a shell script that automates most of the process.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Setup Script](#setup-script)
3. [Usage Instructions](#usage-instructions)
4. [Post-Installation Steps](#post-installation-steps)
5. [High Availability Setup](#high-availability-setup)
6. [Security Considerations](#security-considerations)

## Prerequisites

- One or more servers running a compatible operating system (e.g., Ubuntu 20.04 LTS)
- Root or sudo access on all servers
- Internet connectivity on all servers

## Setup Script

Save the following script as `k3s_full_setup.sh`:

```bash
#!/bin/bash

# Function to install K3s
install_k3s() {
    curl -sfL https://get.k3s.io | sh -s - $@
}

# Function to get node token
get_node_token() {
    sudo cat /var/lib/rancher/k3s/server/node-token
}

# Function to install Helm
install_helm() {
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
}

# Function to install ArgoCD
install_argocd() {
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
}

# Function to install Kubernetes Dashboard
install_dashboard() {
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
}

# Main script
echo "Welcome to K3s, Helm, ArgoCD, and Dashboard Setup Script"
echo "1. Standalone K3s"
echo "2. High Availability K3s"
read -p "Choose your setup (1/2): " choice

case $choice in
    1)
        echo "Setting up standalone K3s..."
        install_k3s
        echo "K3s installed successfully in standalone mode."
        ;;
    2)
        echo "Setting up High Availability K3s..."
        read -p "Is this the first server node? (y/n): " is_first_node
        
        if [ "$is_first_node" = "y" ]; then
            echo "Installing first server node..."
            install_k3s server --cluster-init
            echo "First server node installed. Node token:"
            get_node_token
        else
            read -p "Enter the IP of the first server: " first_server_ip
            read -p "Enter the node token: " node_token
            
            echo "Joining the HA cluster..."
            install_k3s server --server https://${first_server_ip}:6443 --token ${node_token}
        fi
        
        echo "K3s installed successfully in HA mode."
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
sleep 30

# Install Helm
echo "Installing Helm..."
install_helm

# Install ArgoCD
echo "Installing ArgoCD..."
install_argocd

# Install Kubernetes Dashboard
echo "Installing Kubernetes Dashboard..."
install_dashboard

echo "Installation complete. Here are your next steps:"
echo "1. To use kubectl: export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
echo "2. To access ArgoCD UI:"
echo "   kubectl get svc -n argocd argocd-server"
echo "   Username: admin"
echo "   Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
echo "3. To access Kubernetes Dashboard:"
echo "   kubectl proxy"
echo "   Then visit: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo "   Use this token to log in:"
kubectl -n kubernetes-dashboard create token admin-user

echo "Remember to secure your cluster and change default passwords in a production environment!"
```

## Usage Instructions

1. Save the script to a file named `k3s_full_setup.sh`.
2. Make the script executable:
   ```
   chmod +x k3s_full_setup.sh
   ```
3. Run the script with sudo privileges:
   ```
   sudo ./k3s_full_setup.sh
   ```
4. Follow the prompts to choose between standalone or HA setup.

## Post-Installation Steps

After running the script, follow these steps:

1. Set up kubectl:
   ```
   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
   ```

2. Access ArgoCD UI:
   - Get the ArgoCD server address:
     ```
     kubectl get svc -n argocd argocd-server
     ```
   - Use these credentials:
     - Username: admin
     - Password: (provided by the script)

3. Access Kubernetes Dashboard:
   - Start the kubectl proxy:
     ```
     kubectl proxy
     ```
   - Visit: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
   - Use the token provided by the script to log in

## High Availability Setup

For an HA setup, you need at least three servers. Follow these steps:

1. On the first server:
   - Run the script and choose option 2 (HA setup)
   - Answer 'y' when asked if this is the first server node
   - Note down the node token displayed

2. On the second and third servers:
   - Run the script and choose option 2 (HA setup)
   - Answer 'n' when asked if this is the first server node
   - Provide the IP of the first server and the node token when prompted

3. Verify the cluster:
   ```
   kubectl get nodes
   ```

## Security Considerations

1. Change default passwords for ArgoCD and Kubernetes Dashboard.
2. Set up proper authentication and authorization for your cluster.
3. Use firewalls to restrict access to your servers.
4. For production use, set up a load balancer in front of your K3s servers.
5. Regularly update K3s, Helm, ArgoCD, and the Kubernetes Dashboard.
6. Implement network policies to control traffic within your cluster.
7. Use secrets management for sensitive information.
8. Regularly backup your etcd data (for HA setup) and other important configurations.

Remember, this setup is a starting point. Adjust the configuration based on your specific requirements and security needs.