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