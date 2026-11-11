# Offline unit tests: the azurerm provider is mocked, so `terraform test` needs no Azure
# account or credentials. They pin the security baseline every AKS cluster from this module gets.

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-4000-8000-000000000000"
    }
  }
}

variables {
  name              = "test"
  location          = "westeurope"
  api_allowed_cidrs = ["203.0.113.10/32"]
}

run "secure_baseline" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.local_account_disabled
    error_message = "Local (static) cluster accounts must be disabled: every login goes through Entra ID."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].azure_rbac_enabled
    error_message = "Kubernetes authorization must use Azure RBAC."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.api_server_access_profile[0].authorized_ip_ranges == toset(["203.0.113.10/32"])
    error_message = "The API server must only accept the allowed CIDRs."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.network_profile[0].network_policy == "cilium" && azurerm_kubernetes_cluster.this.network_profile[0].network_data_plane == "cilium"
    error_message = "NetworkPolicy must be enforced by the Cilium data plane."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.oidc_issuer_enabled && azurerm_kubernetes_cluster.this.workload_identity_enabled
    error_message = "Workload identity (OIDC issuer) must be on so pods never need stored cloud credentials."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].host_encryption_enabled && azurerm_kubernetes_cluster_node_pool.gpu.host_encryption_enabled
    error_message = "Every node pool must encrypt at the host."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].only_critical_addons_enabled
    error_message = "The system pool must only run critical add-ons; workloads go to other pools."
  }

  assert {
    condition     = contains(azurerm_kubernetes_cluster_node_pool.gpu.node_taints, "nvidia.com/gpu=true:NoSchedule")
    error_message = "GPU nodes must be tainted so only GPU workloads land on them."
  }

  assert {
    condition     = azurerm_kubernetes_cluster_node_pool.gpu.node_labels["nvidia.com/gpu.present"] == "true"
    error_message = "GPU nodes need the label the platform's workloads and Kueue select on."
  }
}

run "rejects_api_open_to_the_internet" {
  command = plan

  variables {
    api_allowed_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.api_allowed_cidrs]
}

run "rejects_an_empty_api_allowlist" {
  command = plan

  variables {
    api_allowed_cidrs = []
  }

  expect_failures = [var.api_allowed_cidrs]
}
