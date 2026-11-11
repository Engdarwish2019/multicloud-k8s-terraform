output "cluster_name" {
  description = "GKE cluster name."
  value       = module.gke.cluster_name
}

output "kubeconfig_command" {
  description = "Command that adds the cluster to your kubeconfig."
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}
