# 🎓 CAPSTONE PROJECT: Cloud-Native TaskApp Deployment

This repository is a production-grade AWS implementation of the Cloud-Native TaskApp Deployment challenge. It answers the same mission: deploy a highly available, secure, and automated Kubernetes-based TaskApp environment using Terraform, kOps, and AWS managed services.

## The Challenge

You have containerized TaskApp (React frontend, Flask backend, PostgreSQL) and deployed it locally. The next step is to migrate this application to production-grade AWS infrastructure using kOps for Kubernetes management and Terraform for infrastructure provisioning.

The goal is to build a highly available, secure, scalable cluster with automated SSL/TLS, Route53 DNS routing, and infrastructure defined entirely in code.

## What This Repo Delivers

- AWS infrastructure provisioned with Terraform
- Remote state backend in S3 with DynamoDB locking
- Automatic etcd backups to S3
- Modular Terraform for VPC, networking, storage, and billing alerts
- Spot instances for cost savings
- kOps-managed Kubernetes cluster with private topology and multi-AZ deployment
- AWS RDS PostgreSQL database for the application data store
- Ingress-based TLS routing via cert-manager and NGINX
- AWS Secrets Store CSI driver integration for Kubernetes secrets
- Automated deployment and teardown scripts in `scripts/`

## Learning Objectives Covered

- Cloud architecture design across multiple Availability Zones
- Infrastructure as Code with Terraform and remote backend state
- Kubernetes operations using kOps and cluster validation
- Cloud-native security via private networking, IAM, and secret management
- DNS delegation and SSL termination with Route53 and cert-manager
- Configuration management via Ansible for cluster nodes
- Docker multi-stage builds for optimized container images

## Architecture Summary

- `terraform/root/`: the main AWS infrastructure stack, including VPC, public/private subnets, S3 backend bucket, DynamoDB lock table, and billing alerts.
- `kops/`: cluster provisioning helpers and cluster YAML generation for kOps.
- `kops/terraform_rds/`: private PostgreSQL RDS deployment inside the application VPC.
- `kops/terraform_route53/`: Route53 DNS records for the frontend and backend hosts.
- `k8s/`: Kubernetes manifests for frontend/backend deployments, service accounts, secret provider, and ingress routing.
- `scripts/`: scripted automation for setup, validation, and cleanup.

## System Requirements Addressed

- 3-AZ deployment with separate public and private subnets
- Private Kubernetes topology via kOps
- Multi-master control plane and worker node provisioning
- Remote Terraform state with S3 and DynamoDB locking
- Remote etcd backups every 15mins by default
- Spot instance worker nodes on deployment
- Route53-managed DNS for application endpoints
- Automated HTTPS using cert-manager
- Secrets management through AWS secret integration
- Resource requests and limits defined for backend workloads
- RDS database deployment in private subnet group

## Project Structure

- `ansible/` - Ansible playbooks and roles for cluster node configuration and management
- `docs/` - runbook and architecture documentation for deployment steps
- `k8s/` - Kubernetes manifests for application deployment
- `kops/` - kOps configuration and AWS-specific Terraform for RDS and DNS
- `terraform/` - modular AWS infrastructure code
- `scripts/` - deployment and cleanup automation
- `misc/` - Terraform backend configuration asset
- `src/taskapp_backend/` - Flask backend application with multi-stage production Dockerfile
- `src/taskapp_frontend/` - React frontend application with Node.js and nginx multi-stage Dockerfile

## Deployment Quickstart

1. Review `docs/runbook.md` for the authoritative deployment order.
2. Build and push Docker images from the `src/` directory to your container registry.
3. Optionally run `scripts/iam-kops.sh` after replacing placeholders.
4. Run `scripts/terraform-setup.sh` to provision the core AWS infrastructure.
5. Update `scripts/kops-setup.sh` with the VPC ID, subnet IDs, and domain configuration.
6. Run `scripts/kops-setup.sh` to generate `cluster-config.yaml`.
7. Run `scripts/kops-start.sh` to create and validate the Kubernetes cluster.
8. Run `scripts/database.sh` to provision the RDS PostgreSQL database.
9. Use Ansible playbooks in `ansible/` to configure cluster nodes and perform post-deployment tasks.
10. Run `scripts/kubernetes.sh` to install ingress, cert-manager, CSI, and deploy app manifests.
11. Run `scripts/routing.sh` to create Route53 records and enable HTTPS routing.
12. Use `scripts/cleanup.sh` for teardown and resource cleanup.

## Building Docker Images

Before deploying to Kubernetes, build and push container images from the application source:

### Backend Image (Flask API)

```bash
cd src/taskapp_backend
docker build -t <registry>/<project>/taskapp-backend:<tag> .
docker push <registry>/<project>/taskapp-backend:<tag>
```

The backend Dockerfile uses a two-stage build process:
- **Stage 1 (Builder)**: Uses Python 3.11-alpine, installs build dependencies and pip packages into a temporary directory
- **Stage 2 (Runtime)**: Copies only the built packages and application code, removes build dependencies, and runs as a non-privileged user

### Frontend Image (React + NGINX)

```bash
cd src/taskapp_frontend
docker build -t <registry>/<project>/taskapp-frontend:<tag> .
docker push <registry>/<project>/taskapp-frontend:<tag>
```

The frontend Dockerfile uses a two-stage build process:
- **Stage 1 (Builder)**: Uses Node.js 24-alpine, installs dependencies, and builds the Vite application
- **Stage 2 (Runtime)**: Uses nginx:alpine, copies the optimized build artifacts, and serves them via NGINX

After building images, update the `BACKEND_IMG` and `FRONTEND_IMG` variables in `scripts/kubernetes.sh` with your pushed image URIs.

## Ansible Configuration Management

The `ansible/` directory contains playbooks for configuring cluster nodes after provisioning:

- **Inventory**: `ansible/inventory/prod.yml` - Define control plane and worker node hosts by their private IPs
- **Playbook**: `ansible/playbooks/site.yml` - Main playbook that applies the `common` role
- **Common Role**: `ansible/roles/common/tasks/main.yml` - Base configuration tasks (apt updates, package installation, etc.)

To use Ansible for cluster configuration:

1. Update `ansible/inventory/prod.yml` with the private IPs of your control plane and worker nodes from the kOps cluster
2. Ensure SSH access via bastion or VPN to the private cluster nodes
3. Configure `ansible/ansible.cfg` with appropriate settings (bastion host, SSH key, user)
4. Run the playbook: `ansible-playbook -i ansible/inventory/prod.yml ansible/playbooks/site.yml`

## Required Manual Edits

Before running scripts, update the following placeholders:

- `scripts/iam-kops.sh`
  - `<your-username>` → your AWS CLI IAM username
- `scripts/kops-setup.sh`
  - `NAME` → your cluster DNS name
  - `KOPS_STATE_STORE` → your kOps S3 state bucket
  - `AWS_REGION` → your AWS region
  - `VPC_ID` → the VPC ID from Terraform output
  - subnet placeholders → actual private and public subnet IDs
- `scripts/kubernetes.sh`
  - `<iam_account_id>` and `<s3_kops_bucket>` in the OIDC command
  - ensure `NAME` and `AWS_REGION` are exported properly
- `scripts/database.sh`
  - provide the RDS `db_password` variable
  - supply `private_subnet_ids` from Terraform output
- `scripts/routing.sh`
  - use the ingress external IP/DNS for Route53 mapping
- `scripts/cleanup.sh`
  - `<your-kops-bucket-name>` → actual kOps state bucket name
  - ensure `${NAME}` is exported for cluster deletion
- `kops/terraform_route53/route53.tf`
  - replace `terra-hunter.com.` with your registered domain
- `k8s/routing.yaml`
  - update `taskapp.terra-hunter.com` and `api.terra-hunter.com` to match your hostnames

## Notes

- The repository follows the referenced capstone expectations by using Terraform, kOps, and AWS services to deploy TaskApp in a cloud-native fashion.
- This implementation is intended to be adapted with a real registered domain and AWS account details before execution.
- The primary app containers are declared in `k8s/backendDeployment.yaml` and `k8s/frontendDeployment.yaml`.

## Documentation and Presentations

- Cost and usage analysis: `docs/cost-analysis.md`
- Presentation videos:
  - `misc/2026-04-08 15-46-50.mp4`
  - `misc/2026-04-08 16-03-01.mp4`

## Submission Checklist

- [ ] `terraform plan` runs successfully in `terraform/root`
- [ ] `kops create` / `kops update` provisions the cluster in AWS
- [ ] `kops validate cluster` reports a ready cluster
- [ ] Application endpoints are available via HTTPS
- [ ] Database is provisioned privately in AWS RDS
- [ ] Secrets are externally managed, not hardcoded in Git
- [ ] Cleanup process removes AWS resources cleanly

---
.

