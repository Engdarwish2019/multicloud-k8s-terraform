variable "name" {
  description = "Base name for the cluster and its resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version. Null picks the current default."
  type        = string
  default     = null
}

variable "vnet_cidr" {
  description = "Address space for the virtual network."
  type        = string
  default     = "10.30.0.0/16"
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the Kubernetes API server."
  type        = list(string)

  validation {
    condition     = length(var.api_allowed_cidrs) > 0 && alltrue([for c in var.api_allowed_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "Give at least one valid CIDR and never 0.0.0.0/0: the API must not be open to the internet."
  }
}

variable "system_vm_size" {
  description = "VM size for the system node pool (must support ephemeral OS disks)."
  type        = string
  default     = "Standard_D4ds_v5"
}

variable "gpu_vm_size" {
  description = "VM size for the GPU node pool."
  type        = string
  default     = "Standard_NC4as_T4_v3"
}

variable "gpu_node_count" {
  description = "Initial GPU node count. The pool autoscales between 0 and max(gpu_node_count, 1)."
  type        = number
  default     = 0
}

variable "log_retention_days" {
  description = "Retention for the Log Analytics workspace."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
