 # WordPress DevOps Project  

**Author:** Rajan  
**Date:** August 10, 2026  
**Environment:** AlmaLinux 9 VM (devops-server)  
**IP Address:** 192.168.246.100 (Host-Only)

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Linux Foundation](#linux-foundation)
4. [Docker & Docker Compose](#docker--docker-compose)
5. [CI/CD with GitHub Actions](#cicd-with-github-actions)
6. [Kubernetes (k3s) & Advanced Deployment](#kubernetes-k3s--advanced-deployment)
7. [Helm, Prometheus, Grafana & Ansible](#helm-prometheus-grafana--ansible)
8. [Security Notes](#security-notes)
9. [How to Deploy from Scratch](#how-to-deploy-from-scratch)
10. [Verification Checklist](#verification-checklist)
11. [License](#license)

---

## Overview

This project is a **hands-on DevOps learning project** demonstrating the deployment and automation of WordPress using Linux, Docker, GitHub Actions, Kubernetes (k3s), Helm, Prometheus, Grafana, and Ansible.

### What This Project Covers

| | Topic | Status |
| :--- | :--- | :--- |
| | Linux System Administration (AlmaLinux, storage, networking) | ✅ |
| | Containerization (Docker & Docker Compose) | ✅ |
| | CI/CD Automation (GitHub Actions with self‑hosted runner) | ✅ |
| | Container Orchestration (Kubernetes / k3s), HPA, Ingress, PVC | ✅ |
| | Helm, Prometheus, Grafana, Ansible Automation | ✅ |

---

## Project Structure

```
wordpress-deployment/
├── .github/
│   └── workflows/
│       └── deploy.yml              # GitHub Actions CI/CD  
├── k8s/
│   └── wordpress-stack.yaml        # Raw Kubernetes manifests  
├── wordpress-chart/                # Helm Chart 
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── configmap.yaml
│       ├── hpa.yaml
│       ├── ingress.yaml
│       ├── mysql-deploy-svc.yaml
│       ├── namespace.yaml
│       ├── pvc.yaml
│       ├── secret.yaml
│       └── wordpress-deploy-svc.yaml
├── ansible/                        # Ansible Automation  
│   ├── inventory
│   ├── playbook.yml
│   └── roles/
│       ├── common/
│       ├── docker/
│       ├── k3s/
│       ├── helm/
│       ├── wordpress/
│       └── monitoring/
├── .env.example
├── .gitignore
├── docker-compose.yml              # Docker Compose stack  
├── LICENSE
└── README.md                       # This file
```

---

##  Linux Foundation

### What Was Done
- Installed AlmaLinux 9 Minimal.
- Configured a **static IP** (`192.168.246.100`) on the Host-Only adapter.
- Set the hostname to `devops-server`.
- Created a non-root user (`rajan`) with `sudo` privileges.
- Added a 10GB secondary disk, partitioned it (`/dev/sdb1`), formatted it with XFS, and configured a persistent mount point at `/data` via `/etc/fstab`.

### Verification Commands
```bash
hostnamectl
ip a show enp0s8
df -h /data
```

### Persistent Mount (`/etc/fstab`)
```bash
UUID=<DISK_UUID>  /data  xfs  defaults  0  0
```

---

##  Docker & Docker Compose

### What Was Done
- Installed Docker Engine and Docker Compose plugin.
- Deployed a WordPress stack using `docker-compose.yml`.
- Configured **persistent storage** using Docker named volumes (`mysql_data`, `wordpress_data`).
- Created a custom Docker network (`wp-network`) for container-to-container communication.

### Environment File (`.env.example`)
```env
MYSQL_ROOT_PASSWORD=<YOUR_ROOT_PASSWORD>
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_PASSWORD=<YOUR_WORDPRESS_DB_PASSWORD>
```

### Deployment Commands
```bash
docker compose up -d
docker compose ps
```

### Access
Open `http://<VM_PRIVATE_IP>` in your browser.

---

##  CI/CD with GitHub Actions

### What Was Done
- Initialized a Git repository and pushed the code to GitHub.
- Configured a **self-hosted GitHub Actions runner** on the VM (running as a systemd service).
- Created `.github/workflows/deploy.yml` to automatically deploy the Docker Compose stack on every `git push` to the `main` branch.
- Stored database passwords as **GitHub Secrets**.

### Self-Hosted Runner Setup
The runner is installed in `/opt/actions-runner` and runs as a systemd service.

**Check runner status:**
```bash
cd /opt/actions-runner
sudo ./svc.sh status
```

### Trigger the Pipeline
```bash
git add .
git commit -m "Update stack"
git push origin main
```

### Monitor
Go to the **Actions** tab in your GitHub repository.

---

##  Kubernetes (k3s) & Advanced Deployment

### What Was Done
- Installed **k3s** (lightweight Kubernetes) on the VM.
- Configured `kubectl` without `sudo`.
- Installed the **Metrics Server** to enable CPU-based autoscaling.
- Created a combined Kubernetes manifest (`k8s/wordpress-stack.yaml`) containing:
  - **Namespace:** `wordpress`
  - **Secret:** MySQL passwords (using `stringData` placeholders).
  - **ConfigMap:** WordPress environment variables.
  - **PersistentVolume (PV):** 10GB `hostPath` storage at `/data/k8s-mysql`.
  - **PersistentVolumeClaim (PVC):** Requests storage for MySQL.
  - **Deployment & Service:** MySQL (port 3306).
  - **Deployment & Service:** WordPress (port 80).
  - **Ingress:** Routes `wordpress.local` to WordPress via Traefik.
  - **HorizontalPodAutoscaler (HPA):** Scales WordPress from 1 to 3 replicas based on CPU > 50%.

### Deploy on Kubernetes
```bash
kubectl apply -f k8s/wordpress-stack.yaml
```

### Watch Pods Start
```bash
kubectl get pods -n wordpress -w
```

### Verify All Resources
```bash
kubectl get all -n wordpress
```

### Access WordPress on Kubernetes
**Option A – Ingress (Recommended for external access)**

1. Edit your Windows hosts file (`C:\Windows\System32\drivers\etc\hosts`) as Administrator.
2. Add this line:
   ```
   <VM_PRIVATE_IP> wordpress.local
   ```
3. Open your browser and go to `http://wordpress.local`.

**Option B – Port-Forward (Quick testing)**
```bash
kubectl port-forward svc/wordpress-service -n wordpress 8080:80
```
Then open `http://localhost:8080` in your browser.

---

##  Helm, Prometheus, Grafana & Ansible

### What Was Done

#### Helm (Package Manager for Kubernetes)
- Created a reusable Helm chart (`wordpress-chart/`) with templates and `values.yaml`.
- Deployed WordPress with:
  ```bash
  helm install my-wordpress ./wordpress-chart \
    --namespace wordpress-helm --create-namespace \
    --set mysql.rootPassword=<YOUR_PASSWORD> \
    --set mysql.password=<YOUR_PASSWORD> \
    --set replicaCount=2
  ```

#### Prometheus & Grafana (Monitoring)
- Installed the `kube-prometheus-stack` using Helm:
  ```bash
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  helm install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    --set grafana.adminPassword=admin
  ```
- Access Grafana:
  ```bash
  kubectl port-forward service/monitoring-grafana -n monitoring 3000:80 &
  ```
  Open `http://localhost:3000` (admin/admin).

#### Ansible (Automation)
- Created a complete Ansible playbook to automate **everything**  .
- Roles include: `common`, `docker`, `k3s`, `helm`, `wordpress`, `monitoring`.

**Run the playbook:**
```bash
cd ansible
ansible-playbook -i inventory playbook.yml
```

**What the playbook does:**
1. Updates system packages.
2. Installs Docker, k3s, and Helm.
3. Deploys WordPress with Helm (persistent storage, HPA, Ingress).
4. Installs Prometheus and Grafana.

---

## Security Notes

- **No passwords, API keys, or tokens** are committed to this repository.
- Sensitive configuration is provided through environment variables and GitHub Secrets.
- `.env` is excluded from Git using `.gitignore`.
- Kubernetes secrets use `stringData` placeholders; real credentials must be created separately (e.g., using `kubectl create secret` or external vaults).
- MySQL is kept internal and is **not** exposed through a host port.
- The self‑hosted GitHub Actions runner should only execute trusted workflows.
- IP addresses and UUIDs in examples are represented using placeholders.

---

## How to Deploy from Scratch

### On a Fresh AlmaLinux VM:

```bash
# 1. Clone the repository
git clone https://github.com/your-username/wordpress-deployment.git
cd wordpress-deployment

# 2. Install Ansible
sudo dnf install -y ansible

# 3. Run the master automation script
cd ansible
ansible-playbook -i inventory playbook.yml
```

### Verify the Deployment:
```bash
# Check WordPress pods
kubectl get pods -n wordpress-helm

# Check HPA
kubectl get hpa -n wordpress-helm

# Check Ingress
kubectl get ingress -n wordpress-helm

# Access WordPress
curl -H "Host: wordpress.local" http://192.168.246.100
```

---

## Verification Checklist

| Check | Command | Expected |
| :--- | :--- | :--- |
| **WordPress Pods** | `kubectl get pods -n wordpress-helm` | 2 or 3 pods `Running` |
| **MySQL Pod** | `kubectl get pods -n wordpress-helm \| grep mysql` | `Running` |
| **HPA** | `kubectl get hpa -n wordpress-helm` | Min: 1, Max: 3 |
| **Prometheus** | `kubectl get pods -n monitoring \| grep prometheus` | `Running` |
| **Grafana** | `kubectl get pods -n monitoring \| grep grafana` | `Running` |
| **Ingress** | `kubectl get ingress -n wordpress-helm` | Host: `wordpress.local` |
| **WordPress Access** | `curl -H "Host: wordpress.local" http://192.168.246.100` | HTML output |
| **Grafana Access** | `http://localhost:3000` | Login page (admin/admin) |

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

Third-party software, Docker images, Kubernetes, AlmaLinux, WordPress, MySQL, and other dependencies remain subject to their respective licenses.

---

 