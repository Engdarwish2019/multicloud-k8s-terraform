data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "nodes" {
  name                 = "snet-nodes"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 4, 0)]
}

# Subnet NSG with Azure's default rules: VNet traffic allowed, inbound internet denied.
# Add explicit inbound rules here if you expose LoadBalancer services publicly.
resource "azurerm_network_security_group" "nodes" {
  name                = "nsg-${var.name}-nodes"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "nodes" {
  subnet_id                 = azurerm_subnet.nodes.id
  network_security_group_id = azurerm_network_security_group.nodes.id
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

# The cluster identity is created first so it can be granted rights on the subnet
# before the cluster exists (needed for load balancers in a bring-your-own VNet).
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "aks_network" {
  scope                = azurerm_subnet.nodes.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_kubernetes_cluster" "this" {
  #checkov:skip=CKV_AZURE_6:authorized_ip_ranges comes from api_allowed_cidrs, which is required and validated (non-empty, never 0.0.0.0/0).
  #checkov:skip=CKV_AZURE_115:Public API kept for the lab; access limited by authorized IP ranges and Entra ID RBAC.
  #checkov:skip=CKV_AZURE_117:Platform-managed disk encryption plus encryption at host; customer-managed keys need a Key Vault and are out of scope.
  name                = "aks-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Standard"

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  local_account_disabled            = true
  role_based_access_control_enabled = true
  azure_policy_enabled              = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  image_cleaner_enabled             = true
  image_cleaner_interval_hours      = 48

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_vm_size
    vnet_subnet_id               = azurerm_subnet.nodes.id
    auto_scaling_enabled         = true
    min_count                    = 2
    max_count                    = 4
    max_pods                     = 50
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = 100
    host_encryption_enabled      = true
    only_critical_addons_enabled = true
    temporary_name_for_rotation  = "systemtmp"
    zones                        = ["1", "2", "3"]
    tags                         = var.tags

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "10.251.0.0/16"
    dns_service_ip      = "10.251.0.10"
  }

  api_server_access_profile {
    authorized_ip_ranges = var.api_allowed_cidrs
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.this.id
    msi_auth_for_monitoring_enabled = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.aks_network]
}

resource "azurerm_kubernetes_cluster_node_pool" "gpu" {
  name                    = "gpu"
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.this.id
  vm_size                 = var.gpu_vm_size
  vnet_subnet_id          = azurerm_subnet.nodes.id
  auto_scaling_enabled    = true
  min_count               = 0
  max_count               = max(var.gpu_node_count, 1)
  node_count              = var.gpu_node_count
  max_pods                = 50
  os_disk_type            = "Ephemeral"
  os_disk_size_gb         = 128
  host_encryption_enabled = true
  node_taints             = ["nvidia.com/gpu=true:NoSchedule"]
  tags                    = var.tags

  node_labels = {
    "nvidia.com/gpu.present" = "true"
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}
