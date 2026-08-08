# WordPress DevOps Learning Project – Days 1–4 (Sanitized)

**Author:** Rajan  
**Date:** August 8, 2026  
**Environment:** AlmaLinux 9 VM (devops-server)  

> **Security Notice:**  
> All passwords, tokens, IP addresses, and UUIDs are replaced with placeholders.  
> **Do not** commit real secrets to this repository.

---

## Table of Contents

1. [Overview](#overview)
2. [Project Structure](#project-structure)
3. [Files](#files)
   - [README.md](#readmemd)
   - [.env.example](#envexample)
   - [.gitignore](#gitignore)
   - [docker-compose.yml](#docker-composeyml)
   - [k8s/wordpress-stack.yaml](#k8swordpress-stackyaml)
   - [.github/workflows/deploy.yml](#githubworkflowsdeployyml)
   - [LICENSE](#license)
4. [Security Notes](#security-notes)
5. [Manual Steps Before Pushing to GitHub](#manual-steps-before-pushing-to-github)

---

## Overview

This project is a hands‑on DevOps learning project demonstrating the deployment and automation of WordPress using Linux, Docker, GitHub Actions, and Kubernetes (k3s).

It covers:

- ✅ Linux System Administration (AlmaLinux, storage, networking)
- ✅ Containerization (Docker & Docker Compose)
- ✅ CI/CD Automation (GitHub Actions with self‑hosted runner)
- ✅ Container Orchestration (Kubernetes / k3s)
- ✅ Persistent Storage (PV / PVC)
- ✅ Horizontal Pod Autoscaling (HPA)
- ✅ Ingress Routing (Traefik)

---

## Project Structure

```
wordpress-deployment/
├── .github/
│   └── workflows/
│       └── deploy.yml
├── k8s/
│   └── wordpress-stack.yaml
├── .env.example
├── .gitignore
├── docker-compose.yml
├── LICENSE
└── README.md
```

---

## Files

### `README.md` (this file)

You are reading it now. It contains the full documentation and all other files embedded as code blocks.

---

### `.env.example`

Create this file as `.env.example` (replace placeholders with your local values, but **never commit** the real `.env`).

```env
MYSQL_ROOT_PASSWORD=<YOUR_ROOT_PASSWORD>
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
MYSQL_PASSWORD=<YOUR_WORDPRESS_DB_PASSWORD>
```

---

### `.gitignore`

Create this file as `.gitignore`.

```gitignore
# Environment files
.env
.env.*
!.env.example

# Secrets and credentials
*.pem
*.key
*.p12
*.pfx

# SSH
id_rsa
id_rsa.pub

# Kubernetes credentials
kubeconfig
k3s.yaml

# Database dumps
*.sql

# Logs
*.log

# IDE/editor files
.vscode/
.idea/

# OS files
.DS_Store
Thumbs.db
```

---

### `docker-compose.yml`

Create this file as `docker-compose.yml`.

```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0.37
    container_name: mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - wp-network
    restart: unless-stopped
    # MySQL port 3306 is NOT exposed to the host; it is internal.

  wordpress:
    image: wordpress:6.6.1
    container_name: wordpress
    ports:
      - "127.0.0.1:8080:80"   # Local development only – adjust if needed
    environment:
      WORDPRESS_DB_HOST: mysql
      WORDPRESS_DB_USER: ${MYSQL_USER}
      WORDPRESS_DB_PASSWORD: ${MYSQL_PASSWORD}
      WORDPRESS_DB_NAME: ${MYSQL_DATABASE}
    volumes:
      - wordpress_data:/var/www/html/wp-content
    networks:
      - wp-network
    depends_on:
      - mysql
    restart: unless-stopped

volumes:
  mysql_data:
  wordpress_data:

networks:
  wp-network:
    driver: bridge
```

---

### `k8s/wordpress-stack.yaml`

Create this file as `k8s/wordpress-stack.yaml`.  
All secrets use `stringData` with placeholders – **never** commit real Base64‑encoded secrets.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: wordpress
---
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: wordpress
type: Opaque
stringData:
  root-password: <YOUR_ROOT_PASSWORD>
  user-password: <YOUR_WORDPRESS_PASSWORD>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: wordpress-config
  namespace: wordpress
data:
  WORDPRESS_DB_HOST: mysql-service
  WORDPRESS_DB_NAME: wordpress
  WORDPRESS_DB_USER: wpuser
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
  namespace: wordpress
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /data/k8s-mysql
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: wordpress
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: wordpress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0.37
        ports:
        - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: root-password
        - name: MYSQL_DATABASE
          value: wordpress
        - name: MYSQL_USER
          value: wpuser
        - name: MYSQL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: user-password
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  namespace: wordpress
spec:
  selector:
    app: mysql
  ports:
  - protocol: TCP
    port: 3306
    targetPort: 3306
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: wordpress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:6.6.1
        ports:
        - containerPort: 80
        env:
        - name: WORDPRESS_DB_HOST
          valueFrom:
            configMapKeyRef:
              name: wordpress-config
              key: WORDPRESS_DB_HOST
        - name: WORDPRESS_DB_NAME
          valueFrom:
            configMapKeyRef:
              name: wordpress-config
              key: WORDPRESS_DB_NAME
        - name: WORDPRESS_DB_USER
          valueFrom:
            configMapKeyRef:
              name: wordpress-config
              key: WORDPRESS_DB_USER
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: user-password
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress-service
  namespace: wordpress
spec:
  selector:
    app: wordpress
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wordpress-ingress
  namespace: wordpress
spec:
  rules:
  - host: wordpress.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wordpress-service
            port:
              number: 80
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: wordpress-hpa
  namespace: wordpress
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: wordpress
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

---

### `.github/workflows/deploy.yml`

Create this file as `.github/workflows/deploy.yml`.

```yaml
name: Deploy WordPress Stack

on:
  push:
    branches:
      - main

env:
  MYSQL_ROOT_PASSWORD: ${{ secrets.MYSQL_ROOT_PASSWORD }}
  MYSQL_DATABASE: ${{ secrets.MYSQL_DATABASE }}
  MYSQL_USER: ${{ secrets.MYSQL_USER }}
  MYSQL_PASSWORD: ${{ secrets.MYSQL_PASSWORD }}

jobs:
  deploy:
    runs-on: self-hosted

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Verify Docker
        run: |
          docker --version
          docker compose version

      - name: Stop old containers
        run: docker compose down || true
        working-directory: ./

      - name: Pull latest images
        run: docker compose pull
        working-directory: ./

      - name: Start containers
        run: docker compose up -d
        working-directory: ./

      - name: Prune unused Docker objects
        run: docker system prune -f
```

 

 

 

 

 

**End of README**