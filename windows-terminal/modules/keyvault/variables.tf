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

variable "kv_name" {
  type        = string
  description = "Key vault name"
}
