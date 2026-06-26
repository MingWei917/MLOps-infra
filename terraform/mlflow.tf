resource "kubernetes_persistent_volume_claim_v1" "mlflow_data" {
  metadata {
    name      = "mlflow-data-pvc"
    namespace = kubernetes_namespace_v1.mlops.metadata[0].name
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
    create = "15m"
  }
  depends_on = [time_sleep.wait_for_argo]
}

resource "kubernetes_deployment_v1" "mlflow" {
  metadata {
    name      = "mlflow-tracking"
    namespace = kubernetes_namespace_v1.mlops.metadata[0].name
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
  depends_on = [kubernetes_persistent_volume_claim_v1.mlflow_data]
}

resource "kubernetes_service_v1" "mlflow" {
  metadata {
    name      = "mlflow-service"
    namespace = kubernetes_namespace_v1.mlops.metadata[0].name
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
  # Chain the service to the deployment
  depends_on = [kubernetes_deployment_v1.mlflow]
}