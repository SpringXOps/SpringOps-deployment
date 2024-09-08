#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display a colorful welcome message
display_welcome() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                   ║${NC}"
    echo -e "${BLUE}║   ██╗  ██╗     ${RED}███████╗████████╗ █████╗ ██████╗   ${BLUE}║${NC}"
    echo -e "${BLUE}║   ██║ ██╔╝     ${RED}██╔════╝╚══██╔══╝██╔══██╗██╔══██╗  ${BLUE}║${NC}"
    echo -e "${BLUE}║   █████╔╝      ${RED}███████╗   ██║   ███████║██║  ██║  ${BLUE}║${NC}"
    echo -e "${BLUE}║   ██╔═██╗      ${RED}╚════██║   ██║   ██╔══██║██║  ██║  ${BLUE}║${NC}"
    echo -e "${BLUE}║   ██║  ██╗     ${RED}███████║   ██║   ██║  ██║██████╔╝  ${BLUE}║${NC}"
    echo -e "${BLUE}║   ╚═╝  ╚═╝     ${RED}╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═════╝   ${BLUE}║${NC}"
    echo -e "${BLUE}║                                                   ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "   Welcome to the ${BLUE}K${NC} ${RED}STAD${NC} Setup Script"
    echo -e "   ${BLUE}K${NC}3s: ${GREEN}Setup${NC}, ${YELLOW}Troubleshoot${NC}, ${BLUE}And${NC} ${RED}Deploy${NC}"
    echo ""
}
# Function for spinner animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to print colored output
print_color() {
    printf "${1}${2}${NC}\n"
}

# Function to save credentials
save_credentials() {
    local filename="/root/k3s_credentials.log"
    local argocd_password="$1"
    local dashboard_token="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    # Append a separator and timestamp
    echo -e "\n\n========================================" >> "$filename"
    echo "K3s Cluster Credentials - $timestamp" >> "$filename"
    echo "========================================" >> "$filename"

    # Append the new credentials
    echo "ArgoCD:" >> "$filename"
    echo "  Username: admin" >> "$filename"
    echo "  Password: $argocd_password" >> "$filename"
    echo "" >> "$filename"
    echo "Kubernetes Dashboard:" >> "$filename"
    echo "  Token: $dashboard_token" >> "$filename"
    echo "" >> "$filename"
    echo "Remember to keep this file secure and delete it when no longer needed." >> "$filename"

    print_color $GREEN "Credentials appended to $filename"

    # Display a warning about the file
    print_color $YELLOW "WARNING: Credentials are being stored in plain text. Ensure the file is secured and deleted when no longer needed."

    # Optionally, set strict permissions on the file
    chmod 600 "$filename"
    print_color $BLUE "File permissions set to 600 (read/write for owner only)"
}

# Function to install K3s
install_k3s() {
    print_color $BLUE "Installing K3s..."
    curl -sfL https://get.k3s.io | sh -s - $@ &
    spinner $!
    print_color $GREEN "K3s installed successfully."
}

# Function to get node token
get_node_token() {
    sudo cat /var/lib/rancher/k3s/server/node-token
}

# Function to install Helm
install_helm() {
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
}

# Function to verify Helm installation
verify_helm() {
    if ! command -v helm &> /dev/null; then
        print_color $YELLOW "Helm is not installed or not in PATH. Attempting to install..."
        install_helm
    fi
    
    helm version
    if [ $? -ne 0 ]; then
        print_color $RED "Helm installation failed or is not working properly."
        return 1
    else
        print_color $GREEN "Helm is installed and working correctly."
    fi
}

# Function to install ArgoCD
install_argocd() {
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
}

# Function to install Kubernetes Dashboard
install_dashboard() {
    print_color $BLUE "Installing Kubernetes Dashboard..."
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
    print_color $GREEN "Kubernetes Dashboard installed successfully."
}

# Function to delete everything
delete_everything() {
    print_color $YELLOW "Deleting K3s..."
    /usr/local/bin/k3s-uninstall.sh
    
    print_color $YELLOW "Removing Helm..."
    sudo rm -rf /usr/local/bin/helm
    
    print_color $YELLOW "Removing kubectl configuration..."
    rm -rf $HOME/.kube
    
    print_color $GREEN "Everything has been deleted."
}

# Function to add user permissions
add_user_permissions() {
    read -p "Enter the username for kubectl permissions: " username
    
    # Create a service account for the user
    kubectl create serviceaccount $username
    
    # Create a cluster role binding
    cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $username-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: $username
  namespace: default
EOF
    
    print_color $GREEN "Permissions added for user $username"
    print_color $YELLOW "To use kubectl as $username, use the following token:"
    kubectl create token $username
}

# Function to troubleshoot Helm
troubleshoot_helm() {
    print_color $BLUE "Troubleshooting Helm connection to Kubernetes cluster..."

    # Check if kubectl can access the cluster
    if ! kubectl get nodes &> /dev/null; then
        print_color $YELLOW "kubectl cannot access the cluster. Setting KUBECONFIG..."
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        if ! kubectl get nodes &> /dev/null; then
            print_color $RED "kubectl still cannot access the cluster. Please check your K3s installation."
            return 1
        fi
    fi

    print_color $GREEN "kubectl can access the cluster."

    # Check cluster info
    print_color $BLUE "Cluster info:"
    kubectl cluster-info

    # Check K3s service status
    print_color $BLUE "Checking K3s service status..."
    if ! systemctl is-active --quiet k3s; then
        print_color $YELLOW "K3s service is not running. Attempting to start..."
        sudo systemctl start k3s
        sleep 10  # Wait for K3s to start
    fi

    # Check K3s service status again
    if ! systemctl is-active --quiet k3s; then
        print_color $RED "Failed to start K3s service. Please check K3s installation."
        return 1
    fi

    print_color $GREEN "K3s service is running."

    # Check K3s configuration
    print_color $BLUE "Checking K3s configuration..."
    if grep -q "\--bind-address" /etc/systemd/system/k3s.service; then
        bind_address=$(grep "\--bind-address" /etc/systemd/system/k3s.service | awk '{print $2}' | cut -d= -f2)
        print_color $YELLOW "K3s is bound to address: $bind_address"
        print_color $YELLOW "Please use this address instead of localhost in your Helm commands."
    else
        print_color $GREEN "K3s is not bound to a specific address."
    fi

    # Try Helm with explicit kubeconfig
    print_color $BLUE "Trying Helm with explicit kubeconfig..."
    if helm --kubeconfig /etc/rancher/k3s/k3s.yaml ls &> /dev/null; then
        print_color $GREEN "Helm works with explicit kubeconfig. Please use --kubeconfig flag in your Helm commands."
    else
        print_color $RED "Helm still cannot connect to the cluster."
        return 1
    fi

    print_color $GREEN "Troubleshooting complete. If issues persist, please check your network configuration and firewall settings."
}
get_argocd_password() {
    print_color $BLUE "Retrieving ArgoCD initial admin password..."
    
    # Wait for the argocd-initial-admin-secret to be created
    local max_retries=30
    local retry_interval=10
    local retry_count=0
    
    while ! kubectl get secret argocd-initial-admin-secret -n argocd &> /dev/null; do
        if [ $retry_count -ge $max_retries ]; then
            print_color $RED "Timed out waiting for ArgoCD admin secret to be created."
            return 1
        fi
        print_color $YELLOW "Waiting for ArgoCD admin secret to be created... (Attempt $((retry_count+1))/$max_retries)"
        sleep $retry_interval
        ((retry_count++))
    done

    # Extract the password
    local argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    if [ -z "$argocd_password" ]; then
        print_color $RED "Failed to retrieve ArgoCD password."
        return 1
    else
        print_color $GREEN "ArgoCD initial admin password retrieved successfully."
        echo $argocd_password
    fi
}
# Function to install and verify Helm
install_and_verify_helm() {
    print_color $BLUE "Installing Helm..."
    install_helm

    print_color $BLUE "Verifying Helm installation..."
    if ! command -v helm &> /dev/null; then
        print_color $RED "Helm is not installed or not in PATH."
        return 1
    fi

    if ! helm version &> /dev/null; then
        print_color $YELLOW "Helm is installed but not working properly. Troubleshooting..."
        troubleshoot_helm
    else
        print_color $GREEN "Helm is installed and working correctly."
    fi
}

# Function to install NGINX Ingress Controller
install_nginx_ingress() {
    print_color $BLUE "Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
    
    # Wait for the Ingress controller to be ready
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=120s

    print_color $GREEN "NGINX Ingress Controller installed successfully."
}

# Function to install Traefik Ingress Controller
install_traefik_ingress() {
    print_color $BLUE "Installing Traefik Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.10/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
    kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v2.10/docs/content/reference/dynamic-configuration/kubernetes-crd-rbac.yml
    
    cat <<EOF | kubectl apply -f -
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: traefik
  namespace: kube-system
spec:
  repo: https://helm.traefik.io/traefik
  chart: traefik
  version: 10.24.0
  targetNamespace: kube-system
EOF

    # Wait for Traefik to be ready
    kubectl wait --namespace kube-system \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/name=traefik \
      --timeout=120s

    print_color $GREEN "Traefik Ingress Controller installed successfully."
}

# Function to install Cert-Manager
install_cert_manager() {
    print_color $BLUE "Installing Cert-Manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
    
    # Wait for Cert-Manager to be ready
    kubectl wait --namespace cert-manager \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/instance=cert-manager \
      --timeout=120s

    print_color $GREEN "Cert-Manager installed successfully."
}

# Function to create a test certificate with Cert-Manager
create_test_certificate() {
    print_color $BLUE "Creating a test certificate with Cert-Manager..."
    
    # Create a test Issuer
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: default
spec:
  selfSigned: {}
EOF

    # Create a test Certificate
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-cert
  namespace: default
spec:
  dnsNames:
    - example.com
  secretName: test-cert-tls
  issuerRef:
    name: test-selfsigned
    kind: Issuer
EOF

    # Wait for the certificate to be ready
    kubectl wait --namespace default \
      --for=condition=ready certificate \
      --field-selector=metadata.name=test-cert \
      --timeout=60s

    print_color $GREEN "Test certificate created successfully."
}

# Function to set up Ingress and Cert-Manager
setup_ingress_and_cert_manager() {
    print_color $YELLOW "Select Ingress Controller:"
    echo "1. NGINX Ingress"
    echo "2. Traefik Ingress"
    read -p "Enter your choice (1 or 2): " ingress_choice

    case $ingress_choice in
        1)
            install_nginx_ingress
            ;;
        2)
            install_traefik_ingress
            ;;
        *)
            print_color $RED "Invalid choice. Skipping Ingress installation."
            ;;
    esac

    install_cert_manager
    create_test_certificate
}
# Main script
display_welcome
# Main script
print_color $YELLOW "Welcome to K3s, Helm, ArgoCD, and Dashboard Setup Script"
echo "1. Standalone K3s"
echo "2. High Availability K3s"
echo "3. Delete Everything"
echo "4. Add User Permissions"
echo "5. Troubleshoot Helm"
echo "6. Set up Ingress and Cert-Manager"
read -p "Choose your option (1/2/3/4/5/6): " choice

case $choice in
    1)
        print_color $BLUE "Setting up standalone K3s..."
        install_k3s
        print_color $GREEN "K3s installed successfully in standalone mode."
        ;;
    2)
        print_color $BLUE "Setting up High Availability K3s..."
        read -p "Is this the first server node? (y/n): " is_first_node
        
        if [ "$is_first_node" = "y" ]; then
            print_color $BLUE "Installing first server node..."
            install_k3s server --cluster-init
            print_color $GREEN "First server node installed. Node token:"
            get_node_token
        else
            read -p "Enter the IP of the first server: " first_server_ip
            read -p "Enter the node token: " node_token
            
            print_color $BLUE "Joining the HA cluster..."
            install_k3s server --server https://${first_server_ip}:6443 --token ${node_token}
        fi
        
        print_color $GREEN "K3s installed successfully in HA mode."
        ;;
    3)
        print_color $YELLOW "Deleting everything..."
        delete_everything
        exit 0
        ;;
    4)
        print_color $BLUE "Adding user permissions..."
        add_user_permissions
        exit 0
        ;;
    5)
        print_color $BLUE "Troubleshooting Helm..."
        troubleshoot_helm
        exit 0
        ;;
    6)
        print_color $BLUE "Setting up Ingress and Cert-Manager..."
        setup_ingress_and_cert_manager
        exit 0
        ;;
    *)
        print_color $RED "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Wait for K3s to be ready
print_color $BLUE "Waiting for K3s to be ready..."
for i in {1..30}; do
    printf "."
    sleep 1
done
echo

# Install and verify Helm
print_color $BLUE "Installing and verifying Helm..."
install_and_verify_helm

# Install ArgoCD
print_color $BLUE "Installing ArgoCD..."
install_argocd

# Get ArgoCD password
argocd_password=$(get_argocd_password)
if [ $? -ne 0 ]; then
    print_color $RED "Failed to get ArgoCD password. Please check ArgoCD installation."
else
    print_color $GREEN "ArgoCD installed successfully."
fi

# Install Kubernetes Dashboard
print_color $BLUE "Installing Kubernetes Dashboard..."
install_dashboard

# Get Kubernetes Dashboard token
dashboard_token=$(kubectl -n kubernetes-dashboard create token admin-user)

# Save or display credentials
append_credentials "$argocd_password" "$dashboard_token"