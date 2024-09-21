project_root/
├── ansible.cfg
├── inventory/
│   ├── group_vars/
│   │   └── all.yml
│   └── hosts.ini
├── playbooks/
│   ├── install.yml
│   ├── uninstall.yml
│   └── roles/
│       ├── k3s/
│       │   ├── tasks/
│       │   │   ├── main.yml
│       │   │   ├── install_standalone.yml
│       │   │   ├── install_ha.yml
│       │   │   └── uninstall.yml
│       │   └── templates/
│       │       ├── k3s_config.ini.j2
│       │       └── k3s_ha_setup.sh.j2
│       ├── helm/
│       │   └── tasks/
│       │       ├── main.yml
│       │       ├── install.yml
│       │       └── uninstall.yml
│       ├── ingress_nginx/
│       │   ├── tasks/
│       │   │   ├── main.yml
│       │   │   ├── install.yml
│       │   │   └── uninstall.yml
│       │   └── templates/
│       │       └── ingress-values.yaml.j2
│       ├── argocd/
│       │   ├── tasks/
│       │   │   ├── main.yml
│       │   │   ├── install.yml
│       │   │   └── uninstall.yml
│       │   └── templates/
│       │       └── argocd-values.yaml.j2
│       ├── dashboard/
│       │   ├── tasks/
│       │   │   ├── main.yml
│       │   │   ├── install.yml
│       │   │   └── uninstall.yml
│       │   └── templates/
│       │       └── dashboard-values.yaml.j2
│       └── cert_manager/
│           ├── tasks/
│           │   ├── main.yml
│           │   ├── install.yml
│           │   └── uninstall.yml
│           └── templates/
│               └── cert-manager-values.yaml.j2
└── README.md

# Content of key files:

# File: inventory/group_vars/all.yml
---
# K3s Configuration
k3s_version: "v1.30.4+k3s1"
k3s_install_mode: "ha"  # Options: "standalone" or "ha"

# Component versions
helm_version: "v3.12.0"
ingress_nginx_version: "4.7.1"
argocd_version: "5.36.1"
dashboard_version: "6.0.8"
cert_manager_version: "v1.12.0"

# Component toggles
install_helm: true
install_ingress_nginx: true
install_argocd: true
install_dashboard: true
install_cert_manager: true

# Additional configurations
argocd_ingress_host: "argocd.example.com"
dashboard_ingress_host: "dashboard.example.com"

# File: playbooks/install.yml
---
- hosts: k3s_cluster
  roles:
    - k3s

- hosts: k3s_masters[0]
  roles:
    - { role: helm, when: install_helm | bool }
    - { role: ingress_nginx, when: install_ingress_nginx | bool }
    - { role: argocd, when: install_argocd | bool }
    - { role: dashboard, when: install_dashboard | bool }
    - { role: cert_manager, when: install_cert_manager | bool }

# File: playbooks/uninstall.yml
---
- hosts: k3s_masters[0]
  roles:
    - { role: cert_manager, tasks_from: uninstall, when: install_cert_manager | bool }
    - { role: dashboard, tasks_from: uninstall, when: install_dashboard | bool }
    - { role: argocd, tasks_from: uninstall, when: install_argocd | bool }
    - { role: ingress_nginx, tasks_from: uninstall, when: install_ingress_nginx | bool }
    - { role: helm, tasks_from: uninstall, when: install_helm | bool }

- hosts: k3s_cluster
  roles:
    - { role: k3s, tasks_from: uninstall }

# File: playbooks/roles/k3s/tasks/main.yml
---
- include_tasks: install_standalone.yml
  when: 
    - ansible_play_name == "install"
    - k3s_install_mode == "standalone"

- include_tasks: install_ha.yml
  when: 
    - ansible_play_name == "install"
    - k3s_install_mode == "ha"

- include_tasks: uninstall.yml
  when: ansible_play_name == "uninstall"

# File: playbooks/roles/k3s/tasks/install_standalone.yml
---
- name: Install K3s standalone
  shell: |
    curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    --tls-san {{ ansible_host }}
  args:
    creates: /usr/local/bin/k3s

# File: playbooks/roles/k3s/tasks/install_ha.yml
---
- name: Generate K3s config file
  template:
    src: k3s_config.ini.j2
    dest: /tmp/k3s_config.ini
  run_once: true
  delegate_to: "{{ groups['k3s_masters'][0] }}"

- name: Copy K3s HA setup script
  template:
    src: k3s_ha_setup.sh.j2
    dest: /tmp/k3s_ha_setup.sh
    mode: '0755'
  run_once: true
  delegate_to: "{{ groups['k3s_masters'][0] }}"

- name: Run K3s HA setup script
  command: /tmp/k3s_ha_setup.sh
  args:
    chdir: /tmp
  run_once: true
  delegate_to: "{{ groups['k3s_masters'][0] }}"

# File: playbooks/roles/k3s/tasks/uninstall.yml
---
- name: Uninstall K3s
  command: /usr/local/bin/k3s-uninstall.sh
  ignore_errors: yes

# File: playbooks/roles/helm/tasks/install.yml
---
- name: Download Helm
  get_url:
    url: "https://get.helm.sh/helm-{{ helm_version }}-linux-amd64.tar.gz"
    dest: "/tmp/helm-{{ helm_version }}.tar.gz"

- name: Extract Helm
  unarchive:
    src: "/tmp/helm-{{ helm_version }}.tar.gz"
    dest: /tmp
    remote_src: yes

- name: Move Helm binary
  command: "mv /tmp/linux-amd64/helm /usr/local/bin/helm"
  become: yes

# File: playbooks/roles/ingress_nginx/tasks/install.yml
---
- name: Add Ingress Nginx repository
  command: helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

- name: Update Helm repositories
  command: helm repo update

- name: Template Ingress Nginx values
  template:
    src: ingress-values.yaml.j2
    dest: /tmp/ingress-values.yaml

- name: Deploy Ingress Nginx
  command: >
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx
    --version {{ ingress_nginx_version }}
    --namespace ingress-nginx --create-namespace
    -f /tmp/ingress-values.yaml

# File: playbooks/roles/argocd/tasks/install.yml
---
- name: Add ArgoCD repository
  command: helm repo add argo https://argoproj.github.io/argo-helm

- name: Update Helm repositories
  command: helm repo update

- name: Template ArgoCD values
  template:
    src: argocd-values.yaml.j2
    dest: /tmp/argocd-values.yaml

- name: Deploy ArgoCD
  command: >
    helm upgrade --install argocd argo/argo-cd
    --version {{ argocd_version }}
    --namespace argocd --create-namespace
    -f /tmp/argocd-values.yaml

# File: playbooks/roles/dashboard/tasks/install.yml
---
- name: Add Kubernetes Dashboard repository
  command: helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

- name: Update Helm repositories
  command: helm repo update

- name: Template Dashboard values
  template:
    src: dashboard-values.yaml.j2
    dest: /tmp/dashboard-values.yaml

- name: Deploy Kubernetes Dashboard
  command: >
    helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard
    --version {{ dashboard_version }}
    --namespace kubernetes-dashboard --create-namespace
    -f /tmp/dashboard-values.yaml

# File: playbooks/roles/cert_manager/tasks/install.yml
---
- name: Add Jetstack repository
  command: helm repo add jetstack https://charts.jetstack.io

- name: Update Helm repositories
  command: helm repo update

- name: Template cert-manager values
  template:
    src: cert-manager-values.yaml.j2
    dest: /tmp/cert-manager-values.yaml

- name: Deploy cert-manager
  command: >
    helm upgrade --install cert-manager jetstack/cert-manager
    --version {{ cert_manager_version }}
    --namespace cert-manager --create-namespace
    -f /tmp/cert-manager-values.yaml

# File: README.md
# Comprehensive K3s Cluster Setup with Optional Components

This project sets up a K3s cluster (standalone or HA) and optionally installs additional components:
- Helm: Kubernetes package manager
- Ingress-Nginx: Ingress controller
- ArgoCD: GitOps continuous delivery tool
- Kubernetes Dashboard: Web-based Kubernetes user interface
- cert-manager: Certificate management controller

## Prerequisites
- Ansible installed on your local machine
- SSH access to target servers

## Usage
1. Update `inventory/hosts.ini` with your server IPs
2. Adjust variables in `inventory/group_vars/all.yml`:
   - Set `k3s_install_mode` to "standalone" or "ha"
   - Set versions as needed
   - Toggle components on/off using `install_*` variables
3. To install, run:
   ```
   ansible-playbook playbooks/install.yml
   ```
4. To uninstall, run:
   ```
   ansible-playbook playbooks/uninstall.yml
   ```

## Components
- K3s: Lightweight Kubernetes (standalone or HA)
- Helm: Package manager for Kubernetes (optional)
- Ingress-Nginx: Ingress controller (optional)
- ArgoCD: GitOps CD tool (optional)
- Kubernetes Dashboard: Web UI (optional)
- cert-manager: Certificate management (optional)

## Customization
- Modify component configurations in the respective `templates/*.yaml.j2` files
- Add new components by creating new roles and adding them to the install/uninstall playbooks