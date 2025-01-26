variable "prefix" {
  type        = string
  description = "Prefix for all resources"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "northeurope"
}

variable "admin_username" {
  type        = string
  description = "Admin username for the VM"
  default     = "meritouser"
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}
