# Setting up Kubernetes Dashboard on K3s

## 1. Install the Dashboard

First, apply the dashboard manifest:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

## 2. Create an Admin User

Create a file named `dashboard-admin-user.yaml` with the following content:

```yaml
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
```

Apply this configuration:

```bash
kubectl apply -f dashboard-admin-user.yaml
```

## 3. Get the Token for the Admin User

Run the following command to get the token:

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

Save this token as you'll need it to log in to the dashboard.

## 4. Access the Dashboard

K3s doesn't expose the dashboard service externally by default. You have two options to access it:

### Option 1: Use kubectl proxy

1. Run the following command:
   ```bash
   kubectl proxy
   ```
2. Access the dashboard at:
   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

### Option 2: Create a NodePort Service

1. Create a file named `dashboard-nodeport.yaml` with the following content:

   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: kubernetes-dashboard-nodeport
     namespace: kubernetes-dashboard
   spec:
     ports:
     - port: 443
       targetPort: 8443
       nodePort: 30443
     selector:
       k8s-app: kubernetes-dashboard
     type: NodePort
   ```

2. Apply this configuration:
   ```bash
   kubectl apply -f dashboard-nodeport.yaml
   ```

3. Access the dashboard at:
   https://NODE_IP:30443
   (Replace NODE_IP with your K3s node's IP address)

## 5. Log in to the Dashboard

Use the token you obtained in step 3 to log in to the dashboard.

## Security Note

Exposing the dashboard via NodePort is not recommended for production environments. For production use, consider setting up proper authentication and using an Ingress controller with HTTPS.
