resource "kubernetes_secret_v1" "minio_creds" {
  metadata {
    name      = "minio-root-creds"
    namespace = kubernetes_namespace_v1.mlops.metadata[0].name
  }
  data = {
    rootUser     = var.minio_root_user
    rootPassword = var.minio_root_password
  }
  depends_on = [time_sleep.wait_for_cluster]
}

resource "helm_release" "minio" {
  name       = "minio"
  repository = "https://charts.min.io/"
  chart      = "minio"
  namespace  = kubernetes_namespace_v1.mlops.metadata[0].name

  wait                       = false
  disable_openapi_validation = true
  disable_webhooks           = true # Skips failing post-install hooks on weak CI runners

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