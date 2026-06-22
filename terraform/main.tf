# 1. Terraform & Providers Definition
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.33.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "/mnt/c/Users/common/.kube/config"
  config_context = "docker-desktop"
}


provider "helm" {
  kubernetes = {
    config_path    = "/mnt/c/Users/common/.kube/config"
    config_context = "docker-desktop"
  }
}

# 2. Create NameSpace
resource "kubernetes_namespace_v1" "mlops_dev" {
  metadata {
    name = "mlops-dev"
  }
}

# 3. Argo Workflows 
resource "helm_release" "argo_workflows" {
  name       = "argo-workflows"
  #repository = "https://argoproj.github.io/argo-helm"
  #chart      = "argo-workflows"
  chart      = "./argo-workflows.tgz" # Points to your downloaded file
  namespace  = kubernetes_namespace_v1.mlops_dev.metadata[0].name
  timeout = 600
  wait = false
  wait_for_jobs = false
  
}
