variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "owner" {
  description = "Owner identifier used to generate unique resource names (e.g., initials or short name)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.owner))
    error_message = "Owner must be 2-10 lowercase alphanumeric characters."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-invoice-etl"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "sql_database_name" {
  description = "Name of the SQL Database"
  type        = string
  default     = "InvoicesDB"
}

variable "sql_admin_username" {
  description = "SQL Server administrator username"
  type        = string
  sensitive   = true
}

variable "sql_admin_password" {
  description = "SQL Server administrator password"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "InvoiceETL"
    ManagedBy   = "Terraform"
  }
}
