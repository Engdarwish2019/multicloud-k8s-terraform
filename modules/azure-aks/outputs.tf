output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "resource_group_name" {
  description = "Resource group of the cluster."
  value       = azurerm_resource_group.this.name
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL, for workload identity federation."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}
