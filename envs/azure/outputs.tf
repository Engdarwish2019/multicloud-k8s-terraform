output "cluster_name" {
  description = "AKS cluster name."
  value       = module.aks.cluster_name
}

output "kubeconfig_command" {
  description = "Command that adds the cluster to your kubeconfig (Entra ID login through kubelogin)."
  value       = "az aks get-credentials --resource-group ${module.aks.resource_group_name} --name ${module.aks.cluster_name}"
}
