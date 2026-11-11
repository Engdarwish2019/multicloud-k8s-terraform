provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

locals {
  tags = {
    Project   = var.name
    ManagedBy = "terraform"
    Repo      = "multicloud-k8s-terraform"
  }
}

module "eks" {
  source = "../../modules/aws-eks"

  name               = var.name
  kubernetes_version = var.kubernetes_version
  azs                = var.azs
  api_allowed_cidrs  = var.api_allowed_cidrs
  gpu_node_count     = var.gpu_node_count
  tags               = local.tags
}
