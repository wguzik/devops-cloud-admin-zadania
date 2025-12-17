# Managed Identity Configuration Summary

## 🔐 Overview

All resources in this Invoice ETL infrastructure use **Managed Identity** for authentication instead of keys or connection strings. This provides better security and eliminates the need to manage credentials.

## 📊 Managed Identity Assignments

### System-Assigned Managed Identities

| Resource | Type | Purpose |
|----------|------|---------|
| **Function App** | System-Assigned | Processes invoices, accesses storage, AI services, and SQL |
| **Data Factory** | System-Assigned | Orchestrates ETL pipeline, accesses storage, AI services, and SQL |

### Role Assignments Created by Terraform

#### Function App Permissions

| Target Resource | Role | Purpose |
|----------------|------|---------|
| Invoice Storage Account | `Storage Blob Data Contributor` | Read/write invoices to blob containers |
| Function Storage Account | `Storage Blob Data Owner` | Manage Function App internal storage |
| AI Document Intelligence | `Cognitive Services User` | Call Document Intelligence API |
| SQL Database | `db_datareader`, `db_datawriter` | Read/write invoice data (configured post-deployment) |

#### Data Factory Permissions

| Target Resource | Role | Purpose |
|----------------|------|---------|
| Invoice Storage Account | `Storage Blob Data Contributor` | Read/write invoices during ETL |
| AI Document Intelligence | `Cognitive Services User` | Process documents in pipeline |
| SQL Database | `db_datareader`, `db_datawriter` | Load processed data (configured post-deployment) |

## 🔧 Configuration Details

### 1. Storage Account Access

**Configuration**: Automatic via Terraform role assignments

**Function App Settings**:
```json
{
  "STORAGE_ACCOUNT_NAME": "stinvoicedev12345",
  "AzureWebJobsStorage__accountName": "stfuncdev12345"
}
```

**Python Code**:
```python
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

credential = DefaultAzureCredential()
account_url = f"https://{account_name}.blob.core.windows.net"
blob_service_client = BlobServiceClient(account_url, credential=credential)
```

### 2. AI Document Intelligence Access

**Configuration**: Automatic via Terraform role assignments

**Function App Settings**:
```json
{
  "FORM_RECOGNIZER_ENDPOINT": "https://doc-intel-invoice-dev.cognitiveservices.azure.com/"
}
```

**Python Code**:
```python
from azure.identity import DefaultAzureCredential
from azure.ai.formrecognizer import DocumentAnalysisClient

credential = DefaultAzureCredential()
document_client = DocumentAnalysisClient(endpoint, credential=credential)
```

### 3. SQL Database Access

**Configuration**: Manual SQL commands required (see post-deployment setup)

**Function App Settings**:
```json
{
  "SQL_SERVER_FQDN": "sql-invoice-dev-12345.database.windows.net",
  "SQL_DATABASE_NAME": "InvoicesDB"
}
```

**SQL Commands to Execute**:
```sql
-- For Function App
CREATE USER [func-invoice-dev-12345] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [func-invoice-dev-12345];
ALTER ROLE db_datawriter ADD MEMBER [func-invoice-dev-12345];

-- For Data Factory
CREATE USER [adf-invoice-etl-dev] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [adf-invoice-etl-dev];
ALTER ROLE db_datawriter ADD MEMBER [adf-invoice-etl-dev];
```

**Python Code**:
```python
from azure.identity import DefaultAzureCredential
import pyodbc
import struct

credential = DefaultAzureCredential()
token = credential.get_token("https://database.windows.net/.default")
token_bytes = token.token.encode("utf-16-le")
token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)

conn = pyodbc.connect(connection_string, attrs_before={1256: token_struct})
```

### 4. Data Factory Linked Services

All linked services use Managed Identity:

**Blob Storage Linked Service**:
- Authentication: Managed Identity
- Service Endpoint: `https://stinvoicedev12345.blob.core.windows.net`

**SQL Database Linked Service**:
- Authentication: Managed Identity (Active Directory)
- Connection String: `Server=tcp:...;Authentication=Active Directory Managed Identity;`

**Function App Linked Service**:
- Uses Function App host key (required for invoking functions)

## ✅ Benefits of Managed Identity

1. **No Credential Management**: No need to store or rotate keys/passwords
2. **Automatic Rotation**: Azure handles token refresh automatically
3. **Least Privilege**: Each resource has only required permissions
4. **Audit Trail**: All access is logged with the managed identity principal
5. **Simplified Code**: Same code works locally (Azure CLI) and in Azure (Managed Identity)

## 🚀 Post-Deployment Checklist

After `terraform apply`, complete these steps:

- [ ] Connect to SQL Database as Azure AD admin
- [ ] Run SQL commands to grant Function App access
- [ ] Run SQL commands to grant Data Factory access
- [ ] Verify managed identity principals: `terraform output managed_identity_info`
- [ ] Test Function App connection to storage
- [ ] Test Function App connection to AI Document Intelligence
- [ ] Test Function App connection to SQL Database
- [ ] Configure Data Factory pipeline
- [ ] Test end-to-end ETL flow

## 📚 Reference

- **Function App Principal ID**: Use `terraform output function_app_principal_id`
- **Data Factory Principal ID**: Use `terraform output data_factory_principal_id`
- **All Managed Identity Info**: Use `terraform output managed_identity_info`

## 🔍 Troubleshooting

### Issue: "Access Denied" errors

**Solution**: Verify role assignments are complete
```bash
# Check Function App roles
az role assignment list --assignee $(terraform output -raw function_app_principal_id)

# Check Data Factory roles
az role assignment list --assignee $(terraform output -raw data_factory_principal_id)
```

### Issue: SQL connection fails

**Solution**: Ensure SQL users were created
```sql
SELECT name, type_desc FROM sys.database_principals WHERE type IN ('E', 'X');
```

### Issue: Local development fails

**Solution**: Login with Azure CLI
```bash
az login
az account set --subscription "<your-subscription-id>"
```

## 📖 Additional Documentation

- See `function-code-examples.md` for complete Python code samples
- See `post-deployment-setup.md` for detailed SQL configuration steps
- See `setup-sql-managed-identity.sh` for automated SQL setup script
