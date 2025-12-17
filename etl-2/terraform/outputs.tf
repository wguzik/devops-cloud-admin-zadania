output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.invoice_etl.name
}

output "storage_account_name" {
  description = "Name of the invoice storage account"
  value       = azurerm_storage_account.invoice_storage.name
}

output "document_intelligence_endpoint" {
  description = "Endpoint for AI Document Intelligence service"
  value       = azurerm_cognitive_account.document_intelligence.endpoint
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.invoice_sql.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Name of the SQL Database"
  value       = azurerm_mssql_database.invoice_db.name
}

output "function_app_name" {
  description = "Name of the Function App"
  value       = azurerm_linux_function_app.invoice_functions.name
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App"
  value       = azurerm_linux_function_app.invoice_functions.default_hostname
}

output "function_app_url" {
  description = "URL of the Function App"
  value       = "https://${azurerm_linux_function_app.invoice_functions.default_hostname}"
}

output "data_factory_name" {
  description = "Name of the Data Factory"
  value       = azurerm_data_factory.invoice_adf.name
}

output "data_factory_id" {
  description = "ID of the Data Factory"
  value       = azurerm_data_factory.invoice_adf.id
}

output "blob_containers" {
  description = "List of blob containers created"
  value = {
    raw_invoices       = azurerm_storage_container.raw_invoices.name
    processed_invoices = azurerm_storage_container.processed_invoices.name
    rejected_invoices  = azurerm_storage_container.rejected_invoices.name
  }
}

# Managed Identity Outputs
output "function_app_principal_id" {
  description = "Principal ID of the Function App Managed Identity"
  value       = azurerm_linux_function_app.invoice_functions.identity[0].principal_id
}

output "data_factory_principal_id" {
  description = "Principal ID of the Data Factory Managed Identity"
  value       = azurerm_data_factory.invoice_adf.identity[0].principal_id
}

output "managed_identity_info" {
  description = "Managed Identity information for SQL configuration"
  value = {
    function_app_name      = azurerm_linux_function_app.invoice_functions.name
    function_app_principal = azurerm_linux_function_app.invoice_functions.identity[0].principal_id
    data_factory_name      = azurerm_data_factory.invoice_adf.name
    data_factory_principal = azurerm_data_factory.invoice_adf.identity[0].principal_id
  }
}
