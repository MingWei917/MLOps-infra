resource "helm_release" "argo_workflows" {
  name       = "argo-workflows"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-workflows"
  namespace  = kubernetes_namespace_v1.mlops.metadata[0].name

  wait                       = false
  disable_openapi_validation = true
  # Disable CRD installation to prevent KinD API server paralysis
  set = [
    {
      name  = "crds.install"
      value = "false"
    }
  ]

  depends_on = [time_sleep.wait_for_cluster]
}

# Give the API server 60 seconds to digest Argo's massive CRDs
resource "time_sleep" "wait_for_argo" {
  depends_on      = [helm_release.argo_workflows]
  create_duration = "60s"
}