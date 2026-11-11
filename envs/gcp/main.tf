provider "google" {
  project = var.project_id
  region  = var.region
}

module "gke" {
  source = "../../modules/gcp-gke"

  name              = var.name
  project_id        = var.project_id
  region            = var.region
  api_allowed_cidrs = var.api_allowed_cidrs
  gpu_zones         = var.gpu_zones
  gpu_node_count    = var.gpu_node_count

  labels = {
    project    = var.name
    managed-by = "terraform"
  }
}
