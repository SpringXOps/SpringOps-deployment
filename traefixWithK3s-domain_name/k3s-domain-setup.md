# Setting Up Domain Names with K3s

To use a domain name with your K3s cluster, you'll need to follow these steps:

1. Register a domain name
2. Set up DNS
3. Install an Ingress controller (if not already installed)
4. Create an Ingress resource
5. (Optional) Set up SSL/TLS certificates

## 1. Register a Domain Name

If you haven't already, register a domain name with a domain registrar of your choice (e.g., GoDaddy, Namecheap, Google Domains).

## 2. Set up DNS

Configure your DNS settings to point your domain to your K3s cluster's IP address:

- If you're using a cloud provider, point your domain to the Load Balancer IP.
- For on-premises setups, point it to the public IP of your K3s server.

Add an A record in your DNS settings:
```
mydomain.com  A  <Your-K3s-IP-Address>
```

## 3. Install an Ingress Controller

K3s comes with Traefik as the default Ingress controller. If you've disabled it or want to use a different one (like Nginx), you'll need to install it. For this example, we'll assume you're using Traefik.

## 4. Create an Ingress Resource

Create a YAML file named `my-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: mydomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port: 
              number: 80
```

Apply this configuration:

```bash
kubectl apply -f my-ingress.yaml
```

## 5. (Optional) Set up SSL/TLS

For HTTPS, you can use cert-manager to automatically provision and manage TLS certificates.

1. Install cert-manager:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.yaml
```

2. Create an Issuer or ClusterIssuer (for Let's Encrypt):

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
```

3. Update your Ingress to use TLS:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    kubernetes.io/ingress.class: traefik
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - mydomain.com
    secretName: mydomain-tls
  rules:
  - host: mydomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port: 
              number: 80
```

Apply these changes, and cert-manager will automatically provision an SSL certificate for your domain.
