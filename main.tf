# ==========================================
# 1. Variables & Providers
# ==========================================
variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "kube_context" {
  type    = string
  default = null
}

variable "minio_root_user" {
  type      = string
  default   = "minioadmin"
  sensitive = true
}

variable "minio_root_password" {
  type      = string
  default   = "minioadmin"
  sensitive = true
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
    time = {
      source  = "hashicorp/time"
      version = "0.11.1"
    }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

provider "helm" {
  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}

# ==========================================
# 2. Namespace & API Server "Breathing Room"
# ==========================================
resource "kubernetes_namespace_v1" "mlops_dev" {
  metadata {
    name = "mlops-dev"
  }
}

resource "time_sleep" "wait_for_cluster" {
  depends_on      = [kubernetes_namespace_v1.mlops_dev]
  create_duration = "15s"
}

# ==========================================
# 3. Argo Workflows 
# ==========================================
resource "helm_release" "argo_workflows" {
  name                       = "argo-workflows"
  repository                 = "https://argoproj.github.io/argo-helm"
  chart                      = "argo-workflows"
  namespace                  = kubernetes_namespace_v1.mlops_dev.metadata[0].name
  wait                       = false
  disable_openapi_validation = true
  depends_on                 = [time_sleep.wait_for_cluster]
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
  timeouts {
    create = "10m"
  }
  depends_on = [time_sleep.wait_for_cluster]
}

resource "kubernetes_deployment_v1" "mlflow" {
  metadata {
    name      = "mlflow-tracking"
    namespace = kubernetes_namespace_v1.mlops_dev.metadata[0].name
    labels = {
      app = "mlflow"
    }
  }

  wait_for_rollout = false

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "mlflow"
      }
    }
    template {
      metadata {
        labels = {
          app = "mlflow"
        }
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

          # FIX 1: Expanded to multi-line block syntax
          port {
            container_port = 5000
            name           = "http"
          }

          # FIX 1: Expanded to multi-line block syntax
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
resource "kubernetes_secret_v1" "minio_creds" {
  metadata {
    name      = "minio-root-creds"
    namespace = kubernetes_namespace_v1.mlops_dev.metadata[0].name
  }
  data = {
    rootUser     = var.minio_root_user
    rootPassword = var.minio_root_password
  }
  depends_on = [time_sleep.wait_for_cluster]
}

resource "helm_release" "minio" {
  name                       = "minio"
  repository                 = "https://charts.min.io/"
  chart                      = "minio"
  namespace                  = kubernetes_namespace_v1.mlops_dev.metadata[0].name
  wait                       = false
  disable_openapi_validation = true
  disable_webhooks           = true

  # FIX 2: Merged all variables into a SINGLE `set` list
  set = [
    {
      name  = "existingSecret"
      value = kubernetes_secret_v1.minio_creds.metadata[0].name
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

  depends_on = [kubernetes_secret_v1.minio_creds]
}