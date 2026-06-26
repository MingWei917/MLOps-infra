# ==========================================
# MLflow Tracking Server Setup
# ==========================================
# NOTE: We use `local_file` and `kubectl` instead of the Terraform Kubernetes 
# Provider resources. This bypasses the "client rate limiter context deadline 
# exceeded" bug that occurs on low-resource CI/CD runners.

resource "local_file" "mlflow_manifests" {
  content  = <<-EOT
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mlflow-data-pvc
  namespace: ${kubernetes_namespace_v1.mlops.metadata[0].name}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlflow-tracking
  namespace: ${kubernetes_namespace_v1.mlops.metadata[0].name}
  labels:
    app: mlflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mlflow
  template:
    metadata:
      labels:
        app: mlflow
    spec:
      containers:
        - name: mlflow
          image: ghcr.io/mlflow/mlflow:v2.14.0
          command: ["mlflow", "server"]
          args:
            - "--host"
            - "0.0.0.0"
            - "--port"
            - "5000"
            - "--backend-store-uri"
            - "sqlite:////mlflow/mlflow.db"
            - "--default-artifact-root"
            - "/mlflow/artifacts"
            - "--serve-artifacts"
          env:
            - name: MLFLOW_ALLOWED_HOSTS
              value: "*"
          ports:
            - containerPort: 5000
              name: http
          volumeMounts:
            - name: mlflow-storage
              mountPath: /mlflow
      volumes:
        - name: mlflow-storage
          persistentVolumeClaim:
            claimName: mlflow-data-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mlflow-service
  namespace: ${kubernetes_namespace_v1.mlops.metadata[0].name}
spec:
  selector:
    app: mlflow
  ports:
    - port: 5000
      targetPort: 5000
      nodePort: 30500
  type: NodePort
EOT
  filename = "${path.module}/mlflow_manifests.yaml"
}

resource "null_resource" "apply_mlflow" {
  depends_on = [local_file.mlflow_manifests, time_sleep.wait_for_argo]

  triggers = {
    manifest_sha1 = sha1(local_file.mlflow_manifests.content)
    namespace     = var.namespace # Pass the variable into triggers here
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${local_file.mlflow_manifests.filename}"
  }

  provisioner "local-exec" {
    when = destroy
    # Use self.triggers.namespace instead of var.namespace
    command = "kubectl delete pvc mlflow-data-pvc deployment mlflow-tracking service mlflow-service -n ${self.triggers.namespace} --ignore-not-found"
  }
}