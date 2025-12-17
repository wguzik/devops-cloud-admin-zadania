locals {
  # Generate unique resource names based on owner
  owner_prefix = lower(replace(var.owner, "/[^a-z0-9]/", ""))
  
  # Storage account names (must be 3-24 lowercase letters and numbers only)
  storage_account_name   = "${local.owner_prefix}invoice${random_string.unique_suffix.result}"
  function_storage_name  = "${local.owner_prefix}func${random_string.unique_suffix.result}"
  
  # Function App name (globally unique)
  function_app_name = "func-invoice-${var.owner}-${random_string.unique_suffix.result}"
  
  # SQL Server name (globally unique)
  sql_server_name = "sql-invoice-${var.owner}-${random_string.unique_suffix.result}"
  
  # Other resource names (can use standard naming)
  document_intelligence_name = "doc-intel-invoice-${var.owner}"
  app_service_plan_name     = "asp-invoice-${var.owner}"
  data_factory_name         = "adf-invoice-${var.owner}"
  
  # Common tags
  common_tags = merge(
    var.tags,
    {
      Owner = var.owner
    }
  )
}

# Random string for unique resource names
resource "random_string" "unique_suffix" {
  length  = 6
  special = false
  upper   = false
}
