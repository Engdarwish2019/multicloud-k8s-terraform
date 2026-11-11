variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "name" {
  description = "Base name for the cluster."
  type        = string
  default     = "platform-aks"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "westeurope"
}

variable "api_allowed_cidrs" {
  description = "Your public IP range(s) allowed to reach the API."
  type        = list(string)
}

variable "gpu_node_count" {
  description = "Initial GPU nodes (Standard_NC4as_T4_v3)."
  type        = number
  default     = 0
}
