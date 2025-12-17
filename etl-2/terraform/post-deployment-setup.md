# Post-Deployment Setup Guide

This document provides detailed steps for configuring Managed Identity access after Terraform deployment.

## 📋 Prerequisites

After running `terraform apply`, you will need:

1. Azure AD admin access to the SQL Server
2. The names of the Function App and Data Factory (from `terraform output`)

## 🗄️ Step 1: Configure SQL Database Access

### Get Resource Names

```bash
# Get the Function App name
FUNCTION_APP_NAME=$(terraform output -raw function_app_name)

# Get the Data Factory name
DATA_FACTORY_NAME=$(terraform output -raw data_factory_name)

# Get SQL Server FQDN
SQL_SERVER=$(terraform output -raw sql_server_fqdn)

# Get Database name
SQL_DATABASE=$(terraform output -raw sql_database_name)

echo "Function App: $FUNCTION_APP_NAME"
echo "Data Factory: $DATA_FACTORY_NAME"
echo "SQL Server: $SQL_SERVER"
echo "Database: $SQL_DATABASE"
```

### Connect to SQL Database

Option 1: Using Azure CLI and sqlcmd

```bash
# Login with Azure AD
az login

# Connect to database
sqlcmd -S $SQL_SERVER -d $SQL_DATABASE -G
```

Option 2: Using Azure Data Studio or SSMS
- Server: (value from `sql_server_fqdn` output)
- Authentication: Azure Active Directory - Universal with MFA
- Database: (value from `sql_database_name` output)

### Run SQL Commands

Execute the following SQL to grant managed identity access:

```sql
-- Create user for Function App Managed Identity
CREATE USER [<FUNCTION_APP_NAME>] FROM EXTERNAL PROVIDER;
GO

-- Grant permissions to Function App
ALTER ROLE db_datareader ADD MEMBER [<FUNCTION_APP_NAME>];
ALTER ROLE db_datawriter ADD MEMBER [<FUNCTION_APP_NAME>];
GO

-- Create user for Data Factory Managed Identity
CREATE USER [<DATA_FACTORY_NAME>] FROM EXTERNAL PROVIDER;
GO

-- Grant permissions to Data Factory
ALTER ROLE db_datareader ADD MEMBER [<DATA_FACTORY_NAME>];
ALTER ROLE db_datawriter ADD MEMBER [<DATA_FACTORY_NAME>];
GO

-- Verify the users were created
SELECT name, type_desc FROM sys.database_principals WHERE type IN ('E', 'X');
GO
```

Replace `<FUNCTION_APP_NAME>` and `<DATA_FACTORY_NAME>` with the actual names from the output above.

## 🔧 Step 2: Create Database Schema

```sql
-- Create Invoices table
CREATE TABLE Invoices (
    InvoiceID INT IDENTITY(1,1) PRIMARY KEY,
    InvoiceNumber NVARCHAR(100),
    Receiver NVARCHAR(255) NOT NULL,
    Cost DECIMAL(18, 2) NOT NULL,
    InvoiceDate DATE NOT NULL,
    ProcessedDate DATETIME DEFAULT GETDATE(),
    BlobPath NVARCHAR(500),
    ValidationStatus NVARCHAR(50),
    CreatedAt DATETIME DEFAULT GETDATE()
);
GO

-- Create indexes for performance
CREATE INDEX IDX_InvoiceDate ON Invoices(InvoiceDate);
CREATE INDEX IDX_Receiver ON Invoices(Receiver);
GO

-- Verify table was created
SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Invoices';
GO
```

## 📝 Step 3: Update Function App Code

Your Python functions should use Managed Identity for authentication. Here are examples:

### Using Blob Storage with Managed Identity

```python
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
import os

# Get storage account name from environment
storage_account_name = os.environ["STORAGE_ACCOUNT_NAME"]

# Create BlobServiceClient using Managed Identity
credential = DefaultAzureCredential()
blob_service_client = BlobServiceClient(
    account_url=f"https://{storage_account_name}.blob.core.windows.net",
    credential=credential
)

# Use the client
container_client = blob_service_client.get_container_client("raw-invoices")
```

### Using AI Document Intelligence with Managed Identity

```python
from azure.identity import DefaultAzureCredential
from azure.ai.formrecognizer import DocumentAnalysisClient
import os

# Get endpoint from environment
endpoint = os.environ["FORM_RECOGNIZER_ENDPOINT"]

# Create client using Managed Identity
credential = DefaultAzureCredential()
document_client = DocumentAnalysisClient(
    endpoint=endpoint,
    credential=credential
)

# Use the client
poller = document_client.begin_analyze_document_from_url(
    "prebuilt-invoice",
    document_url
)
```

### Using SQL Database with Managed Identity

```python
from azure.identity import DefaultAzureCredential
import pyodbc
import struct
import os

# Get SQL connection details from environment
sql_server = os.environ["SQL_SERVER_FQDN"]
sql_database = os.environ["SQL_DATABASE_NAME"]

# Get access token using Managed Identity
credential = DefaultAzureCredential()
token = credential.get_token("https://database.windows.net/.default")

# Convert token to format required by pyodbc
token_bytes = token.token.encode("UTF-16-LE")
token_struct = struct.pack(f'<I{len(token_bytes)}s', len(token_bytes), token_bytes)

# Create connection string with Managed Identity
connection_string = f"Driver={{ODBC Driver 18 for SQL Server}};Server=tcp:{sql_server},1433;Database={sql_database};Encrypt=yes;TrustServerCertificate=no;"

# Connect using the token
conn = pyodbc.connect(connection_string, attrs_before={1256: token_struct})

# Use the connection
cursor = conn.cursor()
cursor.execute("SELECT * FROM Invoices")
```

### Requirements.txt for Function App

```txt
azure-functions
azure-identity
azure-storage-blob
azure-ai-formrecognizer
pyodbc
```

## ✅ Step 4: Verify Configuration

### Test Blob Storage Access

```python
import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
import os

def main(req: func.HttpRequest) -> func.HttpResponse:
    try:
        storage_account_name = os.environ["STORAGE_ACCOUNT_NAME"]
        credential = DefaultAzureCredential()
        
        blob_service_client = BlobServiceClient(
            account_url=f"https://{storage_account_name}.blob.core.windows.net",
            credential=credential
        )
        
        # List containers to verify access
        containers = [c.name for c in blob_service_client.list_containers()]
        
        return func.HttpResponse(
            f"Successfully connected! Containers: {', '.join(containers)}",
            status_code=200
        )
    except Exception as e:
        return func.HttpResponse(
            f"Error: {str(e)}",
            status_code=500
        )
```

### Test SQL Access

```sql
-- Run from SQL query window to verify permissions
SELECT 
    dp.name AS UserName,
    dp.type_desc AS UserType,
    drp.name AS RoleName
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
LEFT JOIN sys.database_principals drp ON drm.role_principal_id = drp.principal_id
WHERE dp.name IN ('<FUNCTION_APP_NAME>', '<DATA_FACTORY_NAME>')
ORDER BY dp.name, drp.name;
```

## 🔍 Troubleshooting

### Common Issues

1. **"Login failed for user" error**
   - Ensure the managed identity user was created in the SQL database
   - Verify Azure AD authentication is enabled on the SQL Server
   - Check that the managed identity has the correct permissions

2. **"This request is not authorized" for Blob Storage**
   - Verify role assignments were created (check Azure Portal)
   - Role assignments can take a few minutes to propagate
   - Ensure the Function App has System Managed Identity enabled

3. **DefaultAzureCredential fails**
   - In local development, use `az login` first
   - In Azure, ensure System Managed Identity is enabled
   - Check that environment variables are set correctly

### Verify Role Assignments

```bash
# List role assignments for Function App
FUNCTION_APP_ID=$(az functionapp show --name $FUNCTION_APP_NAME --resource-group $(terraform output -raw resource_group_name) --query identity.principalId -o tsv)
az role assignment list --assignee $FUNCTION_APP_ID --all -o table

# List role assignments for Data Factory
ADF_ID=$(az datafactory show --name $DATA_FACTORY_NAME --resource-group $(terraform output -raw resource_group_name) --query identity.principalId -o tsv)
az role assignment list --assignee $ADF_ID --all -o table
```

## 📚 Additional Resources

- [Azure Managed Identity Documentation](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [Azure DefaultAzureCredential](https://docs.microsoft.com/en-us/python/api/azure-identity/azure.identity.defaultazurecredential)
- [SQL Database Azure AD Authentication](https://docs.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-overview)
