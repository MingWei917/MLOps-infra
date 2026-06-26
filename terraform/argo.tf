resource "helm_release" "argo_workflows" {
  name       = "argo-workflows"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-workflows"
  namespace  = kubernetes_namespace_v1.mlops.metadata[0].name

  wait                       = false
  disable_openapi_validation = true
  depends_on                 = [time_sleep.wait_for_cluster]
}