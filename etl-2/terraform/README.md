# Invoice ETL Infrastructure - Terraform

This Terraform configuration deploys the complete infrastructure for the Invoice Processing ETL system as described in the project documentation.

## 📋 Architecture Components

This Terraform setup creates the following Azure resources:

- **Resource Group** - Container for all resources
- **Storage Account** - With 3 containers (raw-invoices, processed-invoices, rejected-invoices)
- **AI Document Intelligence** - For invoice recognition and data extraction
- **SQL Server & Database** - To store structured invoice data
- **Function App** (Linux, Python 3.9) - For invoice processing logic with System Managed Identity
- **App Service Plan** - Consumption plan for Function App
- **Data Factory** - For ETL orchestration with System Managed Identity and linked services
- **Role Assignments** - Managed Identity-based access control for all services

## 🔐 Security - Managed Identity

All service-to-service connections use **Managed Identity** instead of connection strings or keys:

| Source | Target | Role |
|--------|--------|------|
| Function App | Invoice Storage | Storage Blob Data Contributor |
| Function App | Function Storage | Storage Blob Data Owner |
| Function App | AI Document Intelligence | Cognitive Services User |
| Function App | SQL Database | db_datareader, db_datawriter |
| Data Factory | Invoice Storage | Storage Blob Data Contributor |
| Data Factory | AI Document Intelligence | Cognitive Services User |
| Data Factory | SQL Database | db_datareader, db_datawriter |

## 🚀 Prerequisites

1. **Azure CLI** installed and configured
   ```bash
   az login
   az account set --subscription "<your-subscription-id>"
   ```

2. **Terraform** installed (version >= 1.0)
   ```bash
   terraform --version
   ```

3. **Azure Subscription** with sufficient permissions to create resources

## 📝 Setup Instructions

### Step 1: Clone and Navigate

```bash
cd etl-2/terraform
```

### Step 2: Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update the following **REQUIRED** values:

- `storage_account_name` - Must be globally unique (3-24 lowercase letters/numbers)
- `sql_server_name` - Must be globally unique
- `sql_admin_username` - SQL admin username
- `sql_admin_password` - **Strong password required!**
- `function_storage_name` - Must be globally unique (3-24 lowercase letters/numbers)
- `function_app_name` - Must be globally unique

**⚠️ IMPORTANT**: Change default passwords and ensure unique names for globally unique resources!

### Step 3: Initialize Terraform

```bash
terraform init
```

### Step 4: Review the Plan

```bash
terraform plan
```

Review the resources that will be created.

### Step 5: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm deployment.

⏱️ **Deployment time**: Approximately 5-10 minutes

## 📤 Outputs

After successful deployment, Terraform will output:

- Storage account connection strings
- Document Intelligence endpoint and keys
- SQL Server FQDN
- Function App URL
- Data Factory information
- Blob container names

To view outputs again:

```bash
terraform output
```

To view sensitive outputs:

```bash
terraform output -json
```

## 🗄️ SQL Database Setup

After deployment, connect to the SQL Database and configure Managed Identity access and create tables:

### Step 1: Configure Managed Identity Access

Connect as Azure AD Admin and run these commands:

```sql
-- Grant access to Function App
CREATE USER [<function_app_name>] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [<function_app_name>];
ALTER ROLE db_datawriter ADD MEMBER [<function_app_name>];

-- Grant access to Data Factory
CREATE USER [<data_factory_name>] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [<data_factory_name>];
ALTER ROLE db_datawriter ADD MEMBER [<data_factory_name>];
```

Replace `<function_app_name>` and `<data_factory_name>` with the actual resource names from your terraform.tfvars.

### Step 2: Create Invoice Table

```sql
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

CREATE INDEX IDX_InvoiceDate ON Invoices(InvoiceDate);
CREATE INDEX IDX_Receiver ON Invoices(Receiver);
```

### Connect Using Azure AD Authentication

```bash
# Get connection details
terraform output sql_server_fqdn
terraform output sql_database_name

# Connect via Azure Data Studio or SSMS using Azure AD authentication
# Or use Azure CLI:
az sql db show-connection-string --client sqlcmd --name $(terraform output -raw sql_database_name) --server $(terraform output -raw sql_server_fqdn) --auth-type ADIntegrated
```

## 🔧 Post-Deployment Steps

1. **Configure SQL Database Managed Identity Access** (Required first!)
   - Follow the SQL Database Setup section above
   - Grant permissions to Function App and Data Factory managed identities

2. **Deploy Function App Code**
   - Deploy the Python functions for invoice upload, validation, and extraction
   - Update code to use Managed Identity for authentication:
     - Use `DefaultAzureCredential()` for Blob Storage access
     - Use `DefaultAzureCredential()` for AI Document Intelligence
     - Use `DefaultAzureCredential()` for SQL Database connections
   - Use Azure Functions Core Tools or VS Code

3. **Configure Data Factory Pipeline**
   - Create the pipeline in Azure Portal using the linked services
   - Set up blob event trigger
   - Configure activities as per documentation

4. **Test the System**
   - Upload a test invoice via Function App
   - Monitor Data Factory pipeline execution
   - Verify data in SQL Database

## 🧹 Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` when prompted.

## 📂 File Structure

```
terraform/
├── main.tf                     # Main resource definitions
├── variables.tf                # Variable declarations
├── outputs.tf                  # Output definitions
├── providers.tf                # Provider configuration
├── terraform.tfvars.example    # Example variables file
└── README.md                   # This file
```

## 🔐 Security Notes

- **Managed Identity is used for all service-to-service connections** - No secrets in configuration
- SQL admin credentials are only for initial setup and emergency access
- SQL passwords are marked as sensitive in Terraform
- Storage account uses role-based access control (RBAC) instead of keys
- AI Document Intelligence uses RBAC instead of API keys
- Function App uses System Managed Identity for authentication
- Data Factory uses System Managed Identity for all linked services
- Consider using Azure Key Vault for the SQL admin password in production
- Enable firewall rules for SQL Server as needed
- Review and restrict function app authentication
- All connections use Azure AD authentication where possible

## 💰 Cost Estimation

Approximate monthly costs (East US, Development):
- Storage Account: ~$1-5
- AI Document Intelligence (S0): ~$1.50/1000 pages
- SQL Database (Basic): ~$5
- Function App (Consumption): Pay per execution
- Data Factory: Pay per activity run

**Total estimated**: $10-50/month for development/testing

## 🆘 Troubleshooting

### Common Issues

1. **Resource name conflicts**
   - Ensure storage account and SQL server names are globally unique
   - Try adding random suffix: `stinvoice${random_id}`

2. **Permission errors**
   - Verify Azure subscription permissions
   - Check service principal permissions if using one

3. **Function App keys error**
   - May need to run `terraform apply` twice on first deployment
   - Keys are generated after Function App is fully provisioned

## 📚 Additional Resources

- [Azure Terraform Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Data Factory Documentation](https://docs.microsoft.com/azure/data-factory/)
- [Azure AI Document Intelligence](https://docs.microsoft.com/azure/applied-ai-services/form-recognizer/)
