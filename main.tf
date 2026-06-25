# ==========================================
# 1. Variables & Providers
# ==========================================
variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config" # Use standard path, override via TF_VAR_kubeconfig_path if needed
}

variable "minio_root_user" {
  description = "MinIO root username"
  type        = string
  default     = "minioadmin"
  sensitive   = true
}

variable "minio_root_password" {
  description = "MinIO root password"
  type        = string
  default     = "minioadmin"
  sensitive   = true
}

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
  config_path    = var.kubeconfig_path
  config_context = "docker-desktop"
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = "docker-desktop"
  }
}

# ==========================================
# 2. Namespace
# ==========================================
resource "kubernetes_namespace_v1" "mlops_dev" {
  metadata {
    name = "mlops-dev"
  }
}

# ==========================================
# 3. Argo Workflows 
# ==========================================
resource "helm_release" "argo_workflows" {
  name       = "argo-workflows"
  repository = "https://argoproj.github.io/argo-helm" # Use remote repo instead of local .tgz
  chart      = "argo-workflows"
  namespace  = kubernetes_namespace_v1.mlops_dev.metadata[0].name
  timeout    = 600
  wait       = false
}

# ==========================================
# 4. MLflow Tracking Server Setup
# ==========================================
resource "kubernetes_persistent_volume_claim_v1" "mlflow_data" {
  metadata {
    name      = "mlflow-data-pvc"
    namespace = kubernetes_namespace_v1.mlops_dev.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "mlflow" {
  metadata {
    name      = "mlflow-tracking"
    namespace = kubernetes_namespace_v1.mlops_dev.metadata[0].name
    labels    = { app = "mlflow" }
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "mlflow" }
    }
    template {
      metadata {
        labels = { app = "mlflow" }
      }
      spec {
        container {
          image = "ghcr.io/mlflow/mlflow:v2.14.0" # FIXED: Changed v3 to v2
          name  = "mlflow"

          command = ["mlflow", "server"]
          args = [
            "--host", "0.0.0.0",
            "--port", "5000",
            "--backend-store-uri", "sqlite:////mlflow/mlflow.db",
            "--default-artifact-root", "/mlflow/artifacts",
            "--serve-artifacts",
          ]

          env {
            name  = "MLFLOW_ALLOWED_HOSTS"
            value = "*"
          }

          port {
            container_port = 5000
            name           = "http"
          }

          volume_mount {
            name       = "mlflow-storage"
            mount_path = "/mlflow"
          }
        }

        volume {
          name = "mlflow-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.mlflow_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "mlflow" {
  metadata {
    name      = "mlflow-service"
    namespace = kubernetes_namespace_v1.mlops_dev.metadata[0].name
  }
  spec {
    selector = {
      app = kubernetes_deployment_v1.mlflow.spec[0].template[0].metadata[0].labels.app
    }
    port {
      port        = 5000
      target_port = 5000
      node_port   = 30500
    }
    type = "NodePort"
  }
}

# ==========================================
# 5. MinIO Object Storage
# ==========================================
resource "helm_release" "minio" {
  name       = "minio"
  repository = "https://charts.min.io/"
  chart      = "minio"
  namespace  = kubernetes_namespace_v1.mlops_dev.metadata[0].name
  timeout    = 600

  set {
    name  = "rootUser"
    value = var.minio_root_user
  }
  set {
    name  = "rootPassword"
    value = var.minio_root_password
  }

  set {
    name  = "persistence.enabled"
    value = "true"
  }
  set {
    name  = "persistence.size"
    value = "5Gi"
  }

  set {
    name  = "service.type"
    value = "NodePort"
  }
  set {
    name  = "service.nodePort"
    value = "30900"
  }

  set {
    name  = "consoleService.type"
    value = "NodePort"
  }
  set {
    name  = "consoleService.nodePort"
    value = "30901"
  }
}