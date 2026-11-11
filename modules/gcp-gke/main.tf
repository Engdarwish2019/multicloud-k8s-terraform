resource "google_compute_network" "this" {
  name                    = var.name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "nodes" {
  #checkov:skip=CKV_GCP_76:IPv4-only lab network; private Google access is enabled.
  name                     = "${var.name}-nodes"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.nodes_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Explicit baseline: internal traffic allowed, everything else from outside denied.
# GKE adds its own higher-priority rules for the control plane and load balancers.
resource "google_compute_firewall" "allow_internal" {
  name      = "${var.name}-allow-internal"
  project   = var.project_id
  network   = google_compute_network.this.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = [var.nodes_cidr, var.pods_cidr, var.services_cidr]

  allow {
    protocol = "all"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "deny_all_ingress" {
  name      = "${var.name}-deny-all-ingress"
  project   = var.project_id
  network   = google_compute_network.this.id
  direction = "INGRESS"
  priority  = 65534

  source_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "this" {
  name    = "${var.name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.this.id
}

# Private nodes reach the internet (image pulls, updates) through Cloud NAT only.
resource "google_compute_router_nat" "this" {
  name                               = "${var.name}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.this.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Dedicated least-privilege node service account instead of the default compute SA.
resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = "${var.name}-nodes"
  display_name = "GKE nodes for ${var.name}"
}

resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  #checkov:skip=CKV_GCP_12:Dataplane V2 (ADVANCED_DATAPATH) enforces NetworkPolicy natively; the legacy network_policy block must stay off.
  #checkov:skip=CKV_GCP_65:Google Groups for RBAC needs a Workspace domain; access is managed with IAM.
  #checkov:skip=CKV_GCP_24:PodSecurityPolicy was removed from Kubernetes; Pod Security admission and Kyverno replace it.
  #checkov:skip=CKV_GCP_20:Master authorized networks are configured through a dynamic block.
  name     = var.name
  project  = var.project_id
  location = var.region

  network    = google_compute_network.this.id
  subnetwork = google_compute_subnetwork.nodes.id

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = var.deletion_protection

  datapath_provider           = "ADVANCED_DATAPATH"
  enable_shielded_nodes       = true
  enable_intranode_visibility = true
  enable_legacy_abac          = false
  resource_labels             = var.labels

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.api_allowed_cidrs

      content {
        cidr_block   = cidr_blocks.value
        display_name = "allowed-${cidr_blocks.key}"
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]

    managed_prometheus {
      enabled = true
    }
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  # Applies only to the temporary default pool that GKE removes right away.
  node_config {
    service_account = google_service_account.nodes.email

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  lifecycle {
    ignore_changes = [node_config]
  }
}

resource "google_container_node_pool" "system" {
  name     = "system"
  project  = var.project_id
  location = var.region
  cluster  = google_container_cluster.this.name

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.system_machine_type
    image_type      = "COS_CONTAINERD"
    disk_type       = "pd-balanced"
    disk_size_gb    = 100
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels          = var.labels

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

resource "google_container_node_pool" "gpu" {
  name               = "gpu"
  project            = var.project_id
  location           = var.region
  cluster            = google_container_cluster.this.name
  node_locations     = length(var.gpu_zones) > 0 ? var.gpu_zones : null
  initial_node_count = var.gpu_node_count

  autoscaling {
    min_node_count = 0
    max_node_count = max(var.gpu_node_count, 1)
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.gpu_machine_type
    image_type      = "COS_CONTAINERD"
    disk_type       = "pd-balanced"
    disk_size_gb    = 100
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = merge(var.labels, {
      "nvidia.com/gpu.present" = "true"
    })

    guest_accelerator {
      type  = var.gpu_type
      count = 1

      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}
