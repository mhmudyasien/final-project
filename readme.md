# Project: DevSecOps Microservices App on AWS

## Project Overview

Build, secure, and deploy a **Microservices (backend + frontend)** application on **AWS** using **EKS (Kubernetes)** and a **DevSecOps pipeline**—integrating security at every stage: code, build, test, and deploy.

**Goal:** Deliver a production-ready, secure microservices application on AWS with infrastructure as code (Terraform), container orchestration (EKS), and security baked in (shift-left).

## Technologies & Tools

### Application Stack
- **Python 3.10 + Flask** for backend microservices
- **React 18** for frontend
- **Docker 24.0** for containerization
- **PostgreSQL 15** (AWS RDS) for data persistence
- **Redis** (AWS ElastiCache) for caching and session management
- **Jest & React Testing Library** for frontend tests | **Pytest** for backend tests
- **Swagger** for API documentation

### AWS Infrastructure
- **Amazon EKS** – Kubernetes cluster for container orchestration
- **Amazon VPC** – Virtual private cloud with subnet isolation
- **Application Load Balancer (ALB)** – Layer 7 load balancing for frontend/backend
- **Amazon RDS PostgreSQL** – Managed database in isolated private subnet
- **Amazon ElastiCache (Redis)** – Managed Redis cluster for caching
- **Amazon ECR** – Container registry for Docker images
- **AWS Secrets Manager** – Secure secrets management
- **Terraform** – Infrastructure as Code (IaC) for AWS resources

### Monitoring & Observability Stack
- **Prometheus** – Metrics collection and time-series database
- **Grafana** – Visualization and dashboards for metrics
- **kube-prometheus-stack** (Prometheus Operator) – Kubernetes-native Prometheus and Grafana deployment
  - Includes: Prometheus Operator, Prometheus, Grafana, Alertmanager
  - Exporters: node-exporter, kube-state-metrics, coredns-exporter
- **Uptime Kuma** – Self-hosted uptime monitoring and status page for site stability
- **kube-state-metrics** – Kubernetes object metrics (pods, deployments, services)

### Logging & Observability (Choose One or Both)

#### Option 1: AWS CloudWatch (Recommended for AWS-native)
- **Amazon CloudWatch Logs** – Centralized log aggregation from EKS pods
- **CloudWatch Logs Insights** – Query and analyze logs with SQL-like queries
- **Fluent Bit** (DaemonSet) – Lightweight log forwarder from EKS to CloudWatch
- **CloudWatch Log Groups** – Organized log storage by namespace/service
- **CloudWatch Alarms** – Alert on log patterns (errors, exceptions)

#### Option 2: ELK Stack (Self-hosted on EKS)
- **Elasticsearch** – Distributed search and analytics engine for log storage
- **Fluent Bit / Fluentd** – Log collection and forwarding agent (DaemonSet)
- **Kibana** – Visualization and exploration of Elasticsearch data
- **Logstash** (optional) – Log processing pipeline (can use Fluent Bit instead)
- **Elasticsearch Operator** – Kubernetes operator for managing Elasticsearch clusters

### CI/CD & Version Control
- **Git** for version control and CI/CD
- **CI/CD** – Pipeline automation
- **Docker Compose** for local development

### Security & Quality (DevSecOps)
- **SonarQube** – SAST, code quality, and security hotspots
- **Trivy** – container and dependency vulnerability scanning
- **OWASP dependency-check** (or similar) – SCA for known CVEs
- **AWS Secrets Manager** – No hardcoded secrets; use Secrets Manager or CI variables
- **SAST/DAST** – Static and (optional) dynamic application security testing in the pipeline
- **AWS Security Hub** (optional) – Centralized security findings
- **Slack** – Security and deployment notifications (e.g. failed scans, deploy success)

## Application Architecture

### 1. Web Application
- Flask REST API backend (containerized)
- React frontend (containerized, served via ALB)
- PostgreSQL database (AWS RDS in private subnet)
- Redis cache (AWS ElastiCache in private subnet)
- Unit tests (Jest, pytest)
- API documentation (Swagger)
- **Security:** No secrets in code; dependency scanning; secure defaults (HTTPS, security headers)

### 2. AWS Infrastructure (Terraform)

#### VPC & Networking
- **VPC** with CIDR block (e.g., `10.0.0.0/16`)
- **Public Subnets** (2+ AZs) – ALB, NAT Gateway
- **Private Subnets** (2+ AZs) – EKS nodes, RDS, ElastiCache
- **Database Subnets** (isolated) – RDS PostgreSQL only
- **Internet Gateway** – Public internet access
- **NAT Gateway** – Outbound internet for private subnets
- **Route Tables** – Proper routing between subnets

#### Compute & Orchestration
- **EKS Cluster** – Kubernetes control plane
- **EKS Node Group** – Managed worker nodes (multi-AZ)
- **Application Load Balancer (ALB)** – Routes traffic to EKS services
- **Target Groups** – Backend API and frontend targets

#### Data Layer
- **RDS PostgreSQL** – Multi-AZ, encrypted at rest, in isolated database subnet
- **ElastiCache Redis** – Multi-AZ cluster, encrypted in transit/at rest, in private subnet
- **Security Groups** – Least-privilege access (EKS → RDS, EKS → ElastiCache)

#### Security & Secrets
- **AWS Secrets Manager** – Database credentials, API keys
- **IAM Roles** – EKS service accounts, node groups, ECR access
- **Security Groups** – Network-level security
- **KMS** – Encryption keys for RDS and ElastiCache

#### Monitoring & Observability

**Metrics (Prometheus + Grafana):**
- **Prometheus** – Deployed via kube-prometheus-stack in EKS
  - Scrapes metrics from: EKS nodes (node-exporter), Kubernetes objects (kube-state-metrics), application endpoints
  - Stores time-series metrics for querying and alerting
- **Grafana** – Deployed via kube-prometheus-stack in EKS
  - Connected to Prometheus as data source
  - Pre-built dashboards for Kubernetes, nodes, and applications
  - Custom dashboards for application metrics
- **Alertmanager** – Handles Prometheus alerts and routes to Slack/email
- **Uptime Kuma** – Deployed in EKS as separate deployment
  - Monitors ALB endpoints (frontend and backend)
  - HTTP/HTTPS checks, TCP checks, DNS checks
  - Status page for public visibility
  - Alerts on downtime
- **ServiceMonitors & PodMonitors** – Kubernetes CRDs for Prometheus to discover scrape targets

**Logging & Observability:**

**Option 1: AWS CloudWatch (AWS-native):**
- **Fluent Bit DaemonSet** – Collects logs from all pods and forwards to CloudWatch Logs
- **CloudWatch Log Groups** – Organized by namespace/service (e.g., `/aws/eks/cluster/app-logs`)
- **CloudWatch Logs Insights** – Query logs with SQL-like
- **CloudWatch Alarms** – Alert on log patterns (error rate, exceptions)
- **IAM Roles** – Fluent Bit service account needs CloudWatch Logs write permissions

**Option 2: ELK Stack (Self-hosted on EKS):**
- **Elasticsearch** – Deployed via Elasticsearch Operator or Helm chart
  - Multi-node cluster for high availability
  - Persistent volumes for data retention
- **Fluent Bit DaemonSet** – Collects logs and forwards to Elasticsearch
- **Kibana** – Deployed as Kubernetes Deployment
  - Connected to Elasticsearch as data source
  - Index patterns for log exploration
  - Dashboards for log visualization
- **Logstash** (optional) – For advanced log processing/transformation

## Deliverables

### Code & Configuration
- **Documented Git repository** (README, architecture, how to run and test)
- **Terraform modules** for:
  - VPC & networking (subnets, IGW, NAT, route tables)
  - EKS cluster & node groups
  - RDS PostgreSQL (multi-AZ, encrypted)
  - ElastiCache Redis (multi-AZ, encrypted)
  - ALB & target groups
  - Security groups & IAM roles
  - Secrets Manager secrets
- **Kubernetes manifests** (Deployments, Services, ConfigMaps, Ingress)
  - Application manifests (frontend, backend)
  - Monitoring stack manifests (Prometheus, Grafana, Uptime Kuma)
  - Observability stack manifests (Fluent Bit, CloudWatch/ELK)
  - ServiceMonitors and PrometheusRules for custom metrics
- **Helm charts** or **kubectl manifests** for:
  - kube-prometheus-stack
  - Fluent Bit (CloudWatch or Elasticsearch output)
  - ELK stack (if using self-hosted option)
- **Terraform modules** for:
  - CloudWatch Log Groups (if using AWS CloudWatch)
  - IAM roles for Fluent Bit service account (IRSA)
- **Dockerfile(s)** (multi-stage, non-root, minimal images)
- **Docker Compose** for local development

### CI/CD Pipeline
- **CI/CD pipeline** with DevSecOps stages
- **ECR integration** – Push images to ECR after security scans pass
- **EKS deployment** – Deploy via kubectl or Helm after infrastructure is ready
- **Security:** No hardcoded secrets; use AWS Secrets Manager or CI variables
- **Slack integration** for pipeline and security notifications

### Documentation
- **Architecture diagram** showing:
  - VPC, subnets, ALB, EKS, RDS, ElastiCache
  - Traffic flow
  - Monitoring stack (Prometheus, Grafana, Uptime Kuma)
  - Observability stack (CloudWatch Logs/ELK, Fluent Bit)
  - Where security runs in the pipeline
- **Terraform documentation** (variables, outputs, module structure)
- **Kubernetes deployment guide**
- **Monitoring setup guide** including:
  - kube-prometheus-stack Helm chart installation
  - Prometheus configuration (ServiceMonitors, PrometheusRules)
  - Grafana dashboard setup and data source configuration
  - Uptime Kuma deployment and ALB endpoint configuration
  - Alertmanager notification channels (Slack, email)
- **Observability/Logging setup guide** including:
  - **CloudWatch Option:** Fluent Bit configuration, IAM roles (IRSA), CloudWatch Logs Insights queries
  - **ELK Option:** Elasticsearch cluster deployment, Fluent Bit → Elasticsearch configuration, Kibana setup and dashboards
  - Log collection from application pods
  - Log retention and indexing strategies


*This project demonstrates a full AWS DevSecOps flow: secure code, secure build, secure infrastructure (Terraform), secure deploy (EKS), secure operations, and comprehensive observability.*
