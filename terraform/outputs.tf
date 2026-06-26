output "mlflow_tracking_uri" {
  description = "The URL for the MLflow tracking server"
  value       = "http://localhost:30500"
}

output "minio_s3_endpoint" {
  description = "The URL for the MinIO S3 API (Used by DVC)"
  value       = "http://localhost:30900"
}

output "minio_console_url" {
  description = "The URL for the MinIO Web Console"
  value       = "http://localhost:30901"
}

output "namespace" {
  description = "The Kubernetes namespace where MLOps tools are deployed"
  value       = kubernetes_namespace_v1.mlops.metadata[0].name
}

output "minio_root_user" {
  description = "MinIO root username"
  value       = var.minio_root_user
  sensitive   = true
}

output "minio_root_password" {
  description = "MinIO root password"
  value       = var.minio_root_password
  sensitive   = true
}