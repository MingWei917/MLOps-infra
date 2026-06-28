# terraform/outputs.tf

output "mlflow_tracking_uri" {
  description = "The URL for the MLflow tracking server (NodePort for external CI access)"
  value       = "http://localhost:30500"
}

output "minio_s3_endpoint" {
  description = "The URL for the MinIO S3 API (NodePort for external CI access)"
  value       = "http://localhost:30900"
}

output "minio_console_url" {
  description = "The URL for the MinIO Web Console"
  value       = "http://localhost:30901"
}

output "namespace" {
  description = "The Kubernetes namespace where MLOps tools are deployed"
  value       = var.namespace
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