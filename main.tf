# ==========================================
# 1. Variables & Providers
# ==========================================
variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "K8s context to use. Null means use the 'current-context'."
  type        = string
  default     = null
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
      version = ">= 2.17.0"
    }
  }
}

# Locally: Uses your current context (docker-desktop)
# CI/CD: Uses the KinD cluster context created by the GitHub Action
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

provider "helm" {
  # 👇 Note the '=' sign. This is required for Helm provider v3.x
  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
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
  repository = "https://argoproj.github.io/argo-helm"
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
  # Explicit timeout for the PVC creation
  timeouts {
    create = "10m"
  }
}

resource "kubernetes_deployment_v1" "mlflow" {
  metadata {
    name      = "mlflow-tracking"
    namespace = kubernetes_namespace_v1.mlops_dev.metadata[0].name
    labels    = { app = "mlflow" }
  }
  # Don't block Terraform if the pod takes a while to start
  wait_for_rollout = false

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
          image = "ghcr.io/mlflow/mlflow:v2.14.0"
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
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "minio"
  namespace  = kubernetes_namespace_v1.mlops_dev.metadata[0].name
  timeout    = 600
  # Do not wait for MinIO pods to be "Ready"
  wait = false

  set = [
    {
      name  = "rootUser"
      value = var.minio_root_user
    },
    {
      name  = "rootPassword"
      value = var.minio_root_password
    },
    {
      name  = "persistence.enabled"
      value = "true"
    },
    {
      name  = "persistence.size"
      value = "5Gi"
    },
    {
      name  = "service.type"
      value = "NodePort"
    },
    {
      name  = "service.nodePort"
      value = "30900"
    },
    {
      name  = "consoleService.type"
      value = "NodePort"
    },
    {
      name  = "consoleService.nodePort"
      value = "30901"
    }
  ]
}