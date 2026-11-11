# Offline unit tests: the google provider is mocked, so `terraform test` needs no GCP project
# or credentials. They pin the security baseline every GKE cluster from this module gets.

mock_provider "google" {}

variables {
  name              = "test"
  project_id        = "demo-project"
  region            = "europe-west4"
  api_allowed_cidrs = ["203.0.113.10/32"]
}

run "secure_baseline" {
  command = plan

  assert {
    condition     = google_container_cluster.this.private_cluster_config[0].enable_private_nodes
    error_message = "Nodes must have private IPs only."
  }

  assert {
    condition     = toset([for c in google_container_cluster.this.master_authorized_networks_config[0].cidr_blocks : c.cidr_block]) == toset(["203.0.113.10/32"])
    error_message = "The control plane must only accept the allowed CIDRs."
  }

  assert {
    condition     = google_container_cluster.this.workload_identity_config[0].workload_pool == "demo-project.svc.id.goog"
    error_message = "Workload Identity must be on so pods never need service account keys."
  }

  assert {
    condition     = google_container_cluster.this.binary_authorization[0].evaluation_mode == "PROJECT_SINGLETON_POLICY_ENFORCE"
    error_message = "Binary Authorization must be enforced."
  }

  assert {
    condition     = google_container_cluster.this.datapath_provider == "ADVANCED_DATAPATH"
    error_message = "Dataplane V2 must enforce NetworkPolicy."
  }

  assert {
    condition     = google_container_cluster.this.enable_shielded_nodes && !google_container_cluster.this.enable_legacy_abac
    error_message = "Shielded nodes on, legacy ABAC off."
  }

  assert {
    condition     = !google_container_cluster.this.master_auth[0].client_certificate_config[0].issue_client_certificate
    error_message = "No static client certificates."
  }

  assert {
    condition     = alltrue([for p in [google_container_node_pool.system, google_container_node_pool.gpu] : p.node_config[0].workload_metadata_config[0].mode == "GKE_METADATA" && p.node_config[0].shielded_instance_config[0].enable_secure_boot])
    error_message = "Every node pool needs the GKE metadata server (no node credentials for pods) and secure boot."
  }

  assert {
    condition     = google_compute_firewall.deny_all_ingress.priority == 65534 && contains(tolist(google_compute_firewall.deny_all_ingress.source_ranges), "0.0.0.0/0")
    error_message = "A lowest-priority rule must deny all other ingress."
  }
}

run "rejects_api_open_to_the_internet" {
  command = plan

  variables {
    api_allowed_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.api_allowed_cidrs]
}
