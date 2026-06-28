variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context to use. Null means use the 'current-context'."
  type        = string
  default     = null
}

variable "namespace" {
  description = "Kubernetes namespace for MLOps tools"
  type        = string
  default     = "mlops-dev"
}
