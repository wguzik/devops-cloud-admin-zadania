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
}

variable "admin_password" {
  type        = string
  description = "Admin password for the VM"
  sensitive   = true
} 