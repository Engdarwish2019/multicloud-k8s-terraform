provider "azurerm" {
  subscription_id = var.subscription_id

  features {}
}

module "aks" {
  source = "../../modules/azure-aks"

  name              = var.name
  location          = var.location
  api_allowed_cidrs = var.api_allowed_cidrs
  gpu_node_count    = var.gpu_node_count

  tags = {
    Project   = var.name
    ManagedBy = "terraform"
    Repo      = "multicloud-k8s-terraform"
  }
}
