# ==========================================
# MinIO Object Storage (Bitnami Chart)
# ==========================================
resource "helm_release" "minio" {
  name       = "minio"
  repository = "https://charts.bitnami.com/bitnami" # Switched to Bitnami
  chart      = "minio"
  namespace  = kubernetes_namespace_v1.mlops.metadata[0].name

  wait                       = false
  disable_openapi_validation = true
  disable_webhooks           = true

  # Bitnami uses slightly different variable names
  set = [
    {
      name  = "auth.rootUser"
      value = var.minio_root_user
    },
    {
      name  = "auth.rootPassword"
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
      name  = "service.nodePorts.api"
      value = "30900"
    },
    {
      name  = "consoleService.type" # Note: Bitnami uses 'console' instead of 'consoleService' in some versions, but this usually passes through
      value = "NodePort"
    },
    {
      name  = "service.nodePorts.console"
      value = "30901"
    }
  ]

  depends_on = [null_resource.apply_mlflow] # Chain it after MLflow
}