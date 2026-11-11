variable "name" {
  description = "Cluster name."
  type        = string
  default     = "platform-eks"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "azs" {
  description = "Availability zones."
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.36"
}

variable "api_allowed_cidrs" {
  description = "Your public IP range(s) allowed to reach the API, for example [\"203.0.113.10/32\"]."
  type        = list(string)
}

variable "gpu_node_count" {
  description = "Initial GPU nodes (g5.xlarge)."
  type        = number
  default     = 0
}
