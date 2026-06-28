# terraform/outputs.tf
output "mlflow_tracking_uri" {
  value = "http://mlflow-service.mlops-dev.svc.cluster.local:5000" # Internal K8s DNS
}

output "minio_s3_endpoint" {
  value = "http://minio.mlops-dev.svc.cluster.local:9000" # Internal K8s DNS
}

output "minio_root_user" {
  value     = var.minio_root_user
  sensitive = true
}

output "minio_root_password" {
  value     = var.minio_root_password
  sensitive = true
}