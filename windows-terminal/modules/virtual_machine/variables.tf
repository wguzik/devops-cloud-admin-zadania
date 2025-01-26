variable "prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "admin_username" {
  type        = string
  description = "Admin username for the VM"
}

variable "key_vault_id" {
  type        = string
  description = "ID of the key vault"
}

variable "subnet_id" {
  type        = string
  description = "ID of the subnet"
}

variable "vm_name" {
  type        = string
  description = "Name of the VM"
}

