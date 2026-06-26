# MLOps Infrastructure (Terraform)

This directory contains the Terraform IaC to provision the MLOps platform (MLflow, MinIO, Argo Workflows) on a Kubernetes cluster.

## Local Usage
1. Ensure Docker Desktop (with Kubernetes enabled) or Minikube/KinD is running.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and update your context.
3. Run:
   ```bash
   terraform init
   terraform apply