variable "name" {
  description = "Cluster name, also used for the network (lowercase, max 20 characters)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name))
    error_message = "Use 3-20 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the regional cluster."
  type        = string
}

variable "nodes_cidr" {
  description = "Primary range of the node subnet."
  type        = string
  default     = "10.40.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for pods."
  type        = string
  default     = "10.44.0.0/14"
}

variable "services_cidr" {
  description = "Secondary range for services."
  type        = string
  default     = "10.48.0.0/20"
}

variable "master_cidr" {
  description = "/28 range for the private control plane endpoint."
  type        = string
  default     = "172.16.0.0/28"
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API (master authorized networks)."
  type        = list(string)

  validation {
    condition     = length(var.api_allowed_cidrs) > 0 && alltrue([for c in var.api_allowed_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "Give at least one valid CIDR and never 0.0.0.0/0: the API must not be open to the internet."
  }
}

variable "system_machine_type" {
  description = "Machine type for the system node pool."
  type        = string
  default     = "e2-standard-4"
}

variable "gpu_machine_type" {
  description = "Machine type for the GPU node pool."
  type        = string
  default     = "n1-standard-4"
}

variable "gpu_type" {
  description = "Accelerator type attached to each GPU node."
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gpu_zones" {
  description = "Zones for the GPU pool (GPU availability differs per zone). Empty uses the cluster zones."
  type        = list(string)
  default     = []
}

variable "gpu_node_count" {
  description = "Initial GPU nodes per zone. The pool autoscales from 0."
  type        = number
  default     = 0
}

variable "deletion_protection" {
  description = "Protect the cluster from terraform destroy."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels applied to the cluster and nodes."
  type        = map(string)
  default     = {}
}
