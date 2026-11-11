variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "name" {
  description = "Cluster name."
  type        = string
  default     = "platform-gke"
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "europe-west4"
}

variable "api_allowed_cidrs" {
  description = "Your public IP range(s) allowed to reach the API."
  type        = list(string)
}

variable "gpu_zones" {
  description = "Zones with T4 capacity for the GPU pool."
  type        = list(string)
  default     = ["europe-west4-a"]
}

variable "gpu_node_count" {
  description = "Initial GPU nodes per zone."
  type        = number
  default     = 0
}
