resource "kubernetes_namespace_v1" "mlops" {
  metadata {
    name = var.namespace
  }
}

# Gives the KinD API server 15 seconds to stabilize before heavy Helm installs
resource "time_sleep" "wait_for_cluster" {
  depends_on      = [kubernetes_namespace_v1.mlops]
  create_duration = "15s"
}