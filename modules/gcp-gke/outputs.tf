output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.this.name
}

output "endpoint" {
  description = "Kubernetes API endpoint."
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "node_service_account" {
  description = "Service account used by the node pools."
  value       = google_service_account.nodes.email
}
