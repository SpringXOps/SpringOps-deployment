# Spring Cloud Microservices on Kubernetes

This project demonstrates a microservices architecture using Spring Cloud, deployed on Kubernetes (K3s). It includes services for service discovery, configuration management, API gateway, user management, and a PostgreSQL database.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Setup Instructions](#setup-instructions)
   - [K3s Installation](#k3s-installation)
   - [Microservices Deployment](#microservices-deployment)
   - [Database Setup](#database-setup)
4. [Services](#services)
5. [Accessing the Services](#accessing-the-services)
6. [Development](#development)
7. [Troubleshooting](#troubleshooting)

## Architecture Overview

The project consists of the following components:

- Eureka Server: Service discovery
- Config Server: Centralized configuration
- API Gateway: Entry point for client requests
- User Service: Manages user data
- PostgreSQL: Database for storing user information

## Prerequisites

- Linux environment (Ubuntu/Debian recommended)
- Docker
- kubectl
- git

## Setup Instructions

### K3s Installation

1. Save the K3s installation script as `install_k3s.sh`.
2. Make it executable: `chmod +x install_k3s.sh`
3. Run the script as root: `sudo ./install_k3s.sh`

### Microservices Deployment

1. Save the Kubernetes configuration as `spring-cloud-k8s.yaml`.
2. Apply the configuration:
   ```
   kubectl apply -f spring-cloud-k8s.yaml
   ```

### Database Setup

1. Create a directory for the PostgreSQL setup:
   ```
   mkdir postgres_docker_setup && cd postgres_docker_setup
   ```
2. Create `docker-compose.yml` and `init.sql` as specified in the provided script.
3. Run Docker Compose:
   ```
   docker-compose up -d
   ```

## Services

- Eureka Server: Service discovery (Port 8761)
- Config Server: Configuration management (Port 8888)
- API Gateway: API Gateway (Port 8080)
- User Service: User management (Port 8081)
- PostgreSQL: Database (Port 5432)

## Accessing the Services

- Eureka Server: http://NODE_IP:30001
- User Service: http://NODE_IP:30003
- PostgreSQL: NODE_IP:30002

Replace NODE_IP with your K3s node's IP address.

## Development

To make changes to the services:

1. Update the respective service's code.
2. Build a new Docker image and push it to your registry.
3. Update the image in `spring-cloud-k8s.yaml`.
4. Reapply the Kubernetes configuration.

## Troubleshooting

- Check pod status: `kubectl get pods`
- View pod logs: `kubectl logs <pod-name>`
- Check services: `kubectl get services`

For more detailed information, refer to the Kubernetes and Spring Cloud documentation.
