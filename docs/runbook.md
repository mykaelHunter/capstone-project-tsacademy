# Runbook

## Purpose

This runbook provides a step-by-step operational procedure for deploying and tearing down the TaskApp AWS production stack in this repository.

## Prerequisites

- AWS CLI configured with sufficient IAM permissions
- `docker` installed with all dependencies
- `terraform` installed and available on `PATH`
- `kubectl` installed and configured for kOps
- `kops` installed and available on `PATH`
- `helm` installed
- `gettext` installed
- A registered domain name delegated to Route53
- SSH key pair available for cluster access
- The repository checked out locally
- Scripts marked executable (`chmod +x scripts/*.sh` if needed)

## Project Location

All deployment scripts are located in the `scripts/` directory. Run them from the repository root or from the `scripts/` directory using a shell.

## Deployment Order

Follow this order exactly. Each step depends on the previous step's output.

### 2. Build and push container images

Files: `src/taskapp_backend/Dockerfile` and `src/taskapp_frontend/Dockerfile`

Before provisioning infrastructure, build Docker images from the application source and push them to a container registry:

#### Build Backend Image

```bash
cd src/taskapp_backend
docker build -t <your-registry>/taskapp-backend:<version> .
docker push <your-registry>/taskapp-backend:<version>
```

The backend Dockerfile implements a multi-stage build:
- **Stage 1 (Builder)**: Compiles Python dependencies on `python:3.11-alpine` with build tools
- **Stage 2 (Runtime)**: Slim image with only runtime dependencies and application code, runs as non-privileged user

#### Build Frontend Image

- Ensure you have edited the `VITE_API_URL` environment variable to match your domain name

```bash
cd src/taskapp_frontend
docker build -t <your-registry>/taskapp-frontend:<version> .
docker push <your-registry>/taskapp-frontend:<version>
```

The frontend Dockerfile implements a two-stage build:
- **Stage 1 (Builder)**: Builds the Vite React TypeScript application on `node:24-alpine`
- **Stage 2 (Runtime)**: Serves built assets via `nginx:alpine`

After pushing images, note the full image URIs. You will reference them when running `scripts/kubernetes.sh`.

### 2. Optional: IAM setup for kOps

File: `scripts/iam-kops.sh`

- Run:

```bash
cd scripts
./iam-kops.sh
```

This script creates a `kops` IAM group and attaches the required AWS policies for kOps to manage EC2, VPC, S3, Route53, IAM, and related services.

### 3. Provision core AWS infrastructure

File: `scripts/terraform-setup.sh`

- Ensure you have a project name, it will define most of the variable names
- Ensure you provide your email(s) in a list of string format eg `["name@example.com"]`

- Run:

```bash
cd scripts
./terraform-setup.sh
```

- Verify the output and record the following values:
  - VPC ID
  - public subnet IDs
  - private subnet IDs

- If Terraform prompts for variable values, provide them or create a `terraform.tfvars` file in `terraform/root/`.

### 4. Configure kOps cluster

File: `scripts/kops-setup.sh`

- Open `scripts/kops-setup.sh` and update the placeholders:
  - `NAME` → your cluster DNS name (must match Route53 domain)
  - `STATE_STORE` → your kOps state bucket (S3)
  - `AWS_REGION` → your AWS region
  - `VPC_ID` → the VPC ID from Terraform output
  - `PRIVATE_SUBNETS` → private subnet IDs
  - `PUBLIC_SUBNETS` → public subnet IDs

- Run:

```bash
cd scripts
./kops-setup.sh
```

- The script generates `kops/cluster-config.yaml` and may open it for manual review.
- Add the maxPrice variable to configure worker nodes as spot instances

### 5. Create the kOps cluster

File: `scripts/kops-start.sh`

- Open `scripts/kops-start.sh` and update the placeholders:
  - `NAME` → your cluster DNS name (must match Route53 domain)
  - `STATE_STORE` → your kOps state bucket (S3)

- Run:

```bash
cd scripts
./kops-start.sh
```

- Confirm cluster status with:

```bash
kubectl get nodes -o wide
kops validate cluster --wait 15m
```

### 6. Optional: Configure cluster nodes with Ansible

File: `ansible/playbooks/site.yml`

After the kOps cluster is running and validated, use Ansible to apply base system configuration to all nodes:

- Update `ansible/inventory/prod.yml` with the private IP addresses of your cluster nodes:
  - Replace `<control-node-1-private-ip>`, `<control-node-2-private-ip>`, etc. with actual IPs from the kOps cluster
  - Replace `<worker-node-1-private-ip>`, etc. with actual worker node IPs

- Configure SSH access in `ansible/ansible.cfg`:
  - Set the SSH private key path
  - Configure bastion/jump host if needed for private network access
  - Set the SSH user (usually `admin` for Ubuntu-based AMIs)

- Run the Ansible playbook:

```bash
ansible-playbook -i ansible/inventory/prod.yml ansible/playbooks/site.yml
```

This applies the `common` role (base system updates, package installation, etc.) to all host groups. Monitor the output for any configuration errors.

### 7. Provision the database

File: `scripts/database.sh`

- Review `kops/terraform_rds/variables.tf` and prepare values for:
  - `project_name`
  - `db_password`
  - `private_subnet_ids` → It must be a list of strings
  - `aws_region`
  - `account_id`
  - `kops_bucket_name`
  - `cluster_name`
  - `vpc_id`

- If needed, create a `terraform.tfvars` file in `kops/terraform_rds/` with the required values.

- Run:

```bash
cd scripts
./database.sh
```

### 8. Deploy Kubernetes services and application manifests

File: `scripts/kubernetes.sh`

- Open `scripts/kubernetes.sh` and update the placeholders:
  - Ensure `NAME`, `AWS_REGION`, `STATE_STORE`, `ACCOUNT_ID`, `EMAIL`, `BACKEND_IMG` and `FRONTEND_IMG` are exported before running the script, if they are referenced by the script environment.

- Run:

```bash
cd scripts
./kubernetes.sh
```

- Verify deployed resources:

```bash
kubectl get pods --all-namespaces
kubectl get svc -n ingress-nginx
kubectl get ingress
```

### 9. Configure Route53 and traffic routing

File: `scripts/routing.sh`

- Open `scripts/routing.sh` and update the placeholders:
  - `DOMAIN` → your parent domain name
  - `domain_name` → your parent domain with a dot (eg. terra-hunter.com.)  

- Obtain the external DNS name or IP address of the NGINX ingress service:

```bash
kubectl get svc -n ingress-nginx
```

- Create a `kops/terraform_route53/terraform.tfvars` file containing:

```hcl
ingress_lb_dns_name = "<INGRESS_EXTERNAL_DNS>"
```

- Replace `terra-hunter.com.` in `kops/terraform_route53/route53.tf` with your Route53 hosted zone domain if needed.

- Run:

```bash
cd scripts
./routing.sh
```

- Apply ingress routing and TLS manifest:

```bash
kubectl apply -f k8s/routing.yaml
```

### 10. Validate the deployment

- Confirm the application endpoints are available:
  - `https://taskapp.<your-domain>`
  - `https://api.<your-domain>`
- Confirm certificate issuance and HTTPS routing.
- Ensure backend pods have successfully started and are healthy.

### 11. Teardown and cleanup

File: `scripts/cleanup.sh`

- Open `scripts/cleanup.sh` and update:
  - ensure `STATE_STORE` is exported or set in the script environment
  - ensure `NAME` is exported or set in the script environment

- Run:

```bash
cd scripts
./cleanup.sh
```

- This script destroys Route53 records, RDS resources, the kOps cluster, and Terraform-managed infrastructure.

## Troubleshooting

- If Terraform fails on `terraform init` or `terraform apply`, confirm AWS credentials and region configuration.
- If kOps fails to create the cluster, confirm that the S3 state bucket exists and the `KOPS_STATE_STORE` path is correct.
- If ingress resources do not become ready, inspect the NGINX controller logs with `kubectl logs -n ingress-nginx`.
- If certificate issuance fails, confirm `cluster-issuer.yaml` and the cert-manager webhook installation succeeded.

## Notes

- The runbook assumes manual editing of placeholders and does not automate secret values.
- All commands should be run from the `scripts/` directory with an appropriate shell.
- Use `kubectl` and `kops` to validate cluster state after each major step.



