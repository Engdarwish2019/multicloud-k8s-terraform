variable "name" {
  description = "Cluster name, also used for the VPC."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "azs" {
  description = "Availability zones for the subnets (three recommended)."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all zones (cheaper, less resilient)."
  type        = bool
  default     = true
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API endpoint."
  type        = list(string)

  validation {
    condition     = length(var.api_allowed_cidrs) > 0 && alltrue([for c in var.api_allowed_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "Give at least one valid CIDR and never 0.0.0.0/0: the API must not be open to the internet."
  }
}

variable "system_instance_types" {
  description = "Instance types for the system node group."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "gpu_instance_type" {
  description = "Instance type for the GPU node group."
  type        = string
  default     = "g5.xlarge"
}

variable "gpu_node_count" {
  description = "Initial size of the GPU node group. 0 keeps the group but runs no GPU instances."
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
