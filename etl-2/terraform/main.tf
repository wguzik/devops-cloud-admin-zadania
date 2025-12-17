# Resource Group
resource "azurerm_resource_group" "invoice_etl" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

# Storage Account for invoices
resource "azurerm_storage_account" "invoice_storage" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.invoice_etl.name
  location                 = azurerm_resource_group.invoice_etl.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  tags = local.common_tags
}

# Storage Containers
resource "azurerm_storage_container" "raw_invoices" {
  name                  = "raw-invoices"
  storage_account_id    = azurerm_storage_account.invoice_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "processed_invoices" {
  name                  = "processed-invoices"
  storage_account_id    = azurerm_storage_account.invoice_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "rejected_invoices" {
  name                  = "rejected-invoices"
  storage_account_id    = azurerm_storage_account.invoice_storage.id
  container_access_type = "private"
}

# AI Document Intelligence (Form Recognizer)
resource "azurerm_cognitive_account" "document_intelligence" {
  name                = local.document_intelligence_name
  resource_group_name = azurerm_resource_group.invoice_etl.name
  location            = azurerm_resource_group.invoice_etl.location
  kind                = "FormRecognizer"
  sku_name            = "S0"

  tags = local.common_tags
}

# SQL Server
resource "azurerm_mssql_server" "invoice_sql" {
  name                         = local.sql_server_name
  resource_group_name          = azurerm_resource_group.invoice_etl.name
  location                     = azurerm_resource_group.invoice_etl.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password

  azuread_administrator {
    login_username = "AzureAD Admin"
    object_id      = data.azurerm_client_config.current.object_id
  }

  tags = local.common_tags
}

# SQL Database
resource "azurerm_mssql_database" "invoice_db" {
  name      = var.sql_database_name
  server_id = azurerm_mssql_server.invoice_sql.id
  sku_name  = "Basic"

  tags = local.common_tags
}

# SQL Firewall Rule - Allow Azure Services
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.invoice_sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# App Service Plan for Function App
resource "azurerm_service_plan" "function_plan" {
  name                = local.app_service_plan_name
  resource_group_name = azurerm_resource_group.invoice_etl.name
  location            = azurerm_resource_group.invoice_etl.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan
  
  tags = local.common_tags
}

# Storage Account for Function App
resource "azurerm_storage_account" "function_storage" {
  name                     = local.function_storage_name
  resource_group_name      = azurerm_resource_group.invoice_etl.name
  location                 = azurerm_resource_group.invoice_etl.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.common_tags
}

# Function App
resource "azurerm_linux_function_app" "invoice_functions" {
  name                       = local.function_app_name
  resource_group_name        = azurerm_resource_group.invoice_etl.name
  location                   = azurerm_resource_group.invoice_etl.location
  service_plan_id            = azurerm_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_uses_managed_identity = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.9"
    }
  }

  app_settings = {
    "STORAGE_ACCOUNT_NAME"         = azurerm_storage_account.invoice_storage.name
    "FORM_RECOGNIZER_ENDPOINT"     = azurerm_cognitive_account.document_intelligence.endpoint
    "SQL_SERVER_FQDN"              = azurerm_mssql_server.invoice_sql.fully_qualified_domain_name
    "SQL_DATABASE_NAME"            = azurerm_mssql_database.invoice_db.name
    "FUNCTIONS_WORKER_RUNTIME"     = "python"
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.function_storage.name
  }

  tags = local.common_tags
}

# Data Factory
resource "azurerm_data_factory" "invoice_adf" {
  name                = local.data_factory_name
  resource_group_name = azurerm_resource_group.invoice_etl.name
  location            = azurerm_resource_group.invoice_etl.location

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Data Factory Linked Service - Blob Storage
resource "azurerm_data_factory_linked_service_azure_blob_storage" "blob_storage" {
  name            = "BlobStorageLinkedService"
  data_factory_id = azurerm_data_factory.invoice_adf.id
  service_endpoint = azurerm_storage_account.invoice_storage.primary_blob_endpoint
  use_managed_identity = true
}

# Data Factory Linked Service - Azure SQL
resource "azurerm_data_factory_linked_service_azure_sql_database" "sql_database" {
  name              = "SqlDatabaseLinkedService"
  data_factory_id   = azurerm_data_factory.invoice_adf.id
  connection_string = "Server=tcp:${azurerm_mssql_server.invoice_sql.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.invoice_db.name};Authentication=Active Directory Managed Identity;"
}

# Data Factory Linked Service - Azure Function
resource "azurerm_data_factory_linked_service_azure_function" "function_app" {
  name            = "FunctionAppLinkedService"
  data_factory_id = azurerm_data_factory.invoice_adf.id
  url             = "https://${azurerm_linux_function_app.invoice_functions.default_hostname}"
  key             = data.azurerm_function_app_host_keys.function_keys.default_function_key
}

# Data source to get current Azure client config
data "azurerm_client_config" "current" {}

# Data source to get Function App host keys
data "azurerm_function_app_host_keys" "function_keys" {
  name                = azurerm_linux_function_app.invoice_functions.name
  resource_group_name = azurerm_resource_group.invoice_etl.name
  
  depends_on = [azurerm_linux_function_app.invoice_functions]
}

# Role Assignments

# Function App -> Invoice Storage Account (Storage Blob Data Contributor)
resource "azurerm_role_assignment" "function_to_invoice_storage" {
  scope                = azurerm_storage_account.invoice_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.invoice_functions.identity[0].principal_id
}

# Function App -> Function Storage Account (Storage Blob Data Owner)
resource "azurerm_role_assignment" "function_to_function_storage" {
  scope                = azurerm_storage_account.function_storage.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_linux_function_app.invoice_functions.identity[0].principal_id
}

# Function App -> AI Document Intelligence (Cognitive Services User)
resource "azurerm_role_assignment" "function_to_doc_intelligence" {
  scope                = azurerm_cognitive_account.document_intelligence.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_linux_function_app.invoice_functions.identity[0].principal_id
}

# Data Factory -> Invoice Storage Account (Storage Blob Data Contributor)
resource "azurerm_role_assignment" "adf_to_invoice_storage" {
  scope                = azurerm_storage_account.invoice_storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.invoice_adf.identity[0].principal_id
}

# Data Factory -> AI Document Intelligence (Cognitive Services User)
resource "azurerm_role_assignment" "adf_to_doc_intelligence" {
  scope                = azurerm_cognitive_account.document_intelligence.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_data_factory.invoice_adf.identity[0].principal_id
}

# SQL Database Access for Managed Identities
# Note: These need to be configured via SQL after deployment:
# For Function App:
# CREATE USER [${function_app_name}] FROM EXTERNAL PROVIDER;
# ALTER ROLE db_datareader ADD MEMBER [${function_app_name}];
# ALTER ROLE db_datawriter ADD MEMBER [${function_app_name}];
# 
# For Data Factory:
# CREATE USER [${data_factory_name}] FROM EXTERNAL PROVIDER;
# ALTER ROLE db_datareader ADD MEMBER [${data_factory_name}];
# ALTER ROLE db_datawriter ADD MEMBER [${data_factory_name}];
