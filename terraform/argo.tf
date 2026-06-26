resource "helm_release" "argo_workflows" {
  name       = "argo-workflows"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-workflows"
  namespace  = kubernetes_namespace_v1.mlops.metadata[0].name

  wait                       = false
  disable_openapi_validation = true
  depends_on                 = [time_sleep.wait_for_cluster]
}

# Give the API server 30 seconds to digest Argo's massive CRDs
resource "time_sleep" "wait_for_argo" {
  depends_on      = [helm_release.argo_workflows]
  create_duration = "30s"
}