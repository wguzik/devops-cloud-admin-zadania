# Quick Start Guide - Invoice ETL Deployment

## 📁 Project Structure

```
etl-2/
├── functions/                    # Azure Functions code
│   ├── InvoiceUpload/           # Upload invoice to blob storage
│   ├── ValidateInvoice/         # Validate invoice with AI
│   ├── ExtractInvoiceData/      # Extract data and save to SQL
│   ├── requirements.txt         # Python dependencies
│   ├── host.json               # Function app configuration
│   └── README.md               # Functions documentation
│
├── terraform/                   # Infrastructure as Code
│   ├── main.tf                 # Main Terraform configuration
│   ├── variables.tf            # Variable definitions
│   ├── outputs.tf              # Output values
│   ├── providers.tf            # Provider configuration
│   ├── terraform.tfvars.example # Example configuration
│   └── *.md                    # Documentation
│
├── deploy-all.sh               # Complete deployment script
├── deploy-functions.sh         # Deploy functions only
├── test-functions.sh           # Test deployed functions
├── cleanup.sh                  # Destroy all resources
├── DEPLOYMENT-GUIDE.md         # Detailed deployment guide
└── QUICK-START.md              # This file
```

## 🚀 Quick Deployment

### Prerequisites

Install required tools:
- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Azure Functions Core Tools](https://docs.microsoft.com/azure/azure-functions/functions-run-local)
- Python 3.9+

### Step 1: Configure

```bash
# Login to Azure
az login
az account set --subscription "<your-subscription-id>"

# Configure Terraform variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit with your values
```

**Important**: Update these in `terraform.tfvars`:
- `storage_account_name` - Must be globally unique
- `sql_server_name` - Must be globally unique
- `sql_admin_password` - Use a strong password
- `function_storage_name` - Must be globally unique
- `function_app_name` - Must be globally unique

### Step 2: Deploy Everything

```bash
cd ..
./deploy-all.sh
```

This script will:
1. ✅ Check prerequisites
2. ✅ Initialize Terraform
3. ✅ Deploy infrastructure (Function App, Storage, SQL, AI Services, Data Factory)
4. ✅ Configure SQL Database access
5. ✅ Deploy Azure Functions

**Note**: You'll need to manually execute the SQL script for managed identity access.

### Step 3: Configure SQL Access

When prompted, run the generated SQL commands:

```sql
-- The script will generate these for you
CREATE USER [your-function-app-name] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [your-function-app-name];
ALTER ROLE db_datawriter ADD MEMBER [your-function-app-name];

CREATE USER [your-data-factory-name] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [your-data-factory-name];
ALTER ROLE db_datawriter ADD MEMBER [your-data-factory-name];
```

### Step 4: Test Functions

```bash
./test-functions.sh
```

This will test all three functions:
- InvoiceUpload
- ValidateInvoice
- ExtractInvoiceData

## 📝 Individual Deployment Steps

### Deploy Infrastructure Only

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Deploy Functions Only

```bash
./deploy-functions.sh
```

### Test Functions

```bash
./test-functions.sh
```

## 🧪 Manual Testing

### Upload an Invoice

```bash
# Get function details
cd terraform
FUNCTION_URL=$(terraform output -raw function_app_url)
FUNCTION_APP=$(terraform output -raw function_app_name)
RESOURCE_GROUP=$(terraform output -raw resource_group_name)

# Get function key
FUNCTION_KEY=$(az functionapp keys list \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --query "functionKeys.default" -o tsv)

# Upload invoice
curl -X POST "${FUNCTION_URL}/api/InvoiceUpload?code=${FUNCTION_KEY}" \
  -F "invoice=@path/to/invoice.pdf"
```

### Validate Invoice

```bash
curl -X POST "${FUNCTION_URL}/api/ValidateInvoice?code=${FUNCTION_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"blob_url": "https://your-storage.blob.core.windows.net/raw-invoices/invoice.pdf"}'
```

### Extract Invoice Data

```bash
curl -X POST "${FUNCTION_URL}/api/ExtractInvoiceData?code=${FUNCTION_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"blob_url": "https://your-storage.blob.core.windows.net/raw-invoices/invoice.pdf"}'
```

## 📊 View Results

### Check SQL Database

```bash
# Get SQL connection info
cd terraform
SQL_SERVER=$(terraform output -raw sql_server_fqdn)
SQL_DATABASE=$(terraform output -raw sql_database_name)

# Connect and query
sqlcmd -S $SQL_SERVER -d $SQL_DATABASE -G

# Or use Azure Portal Query Editor
```

```sql
SELECT * FROM Invoices ORDER BY CreatedAt DESC;
```

### View Function Logs

```bash
az functionapp log tail \
  --name $(cd terraform && terraform output -raw function_app_name) \
  --resource-group $(cd terraform && terraform output -raw resource_group_name)
```

### Check Blob Storage

```bash
# List uploaded invoices
az storage blob list \
  --account-name $(cd terraform && terraform output -raw storage_account_name) \
  --container-name raw-invoices \
  --auth-mode login
```

## 🔧 Troubleshooting

### Functions can't access storage

```bash
# Verify role assignments
cd terraform
FUNCTION_PRINCIPAL=$(terraform output -raw function_app_principal_id)
az role assignment list --assignee $FUNCTION_PRINCIPAL
```

### SQL connection fails

```sql
-- Verify managed identity users exist
SELECT name, type_desc FROM sys.database_principals WHERE type IN ('E', 'X');
```

### Local development

```bash
cd functions
cp local.settings.json.example local.settings.json
# Edit local.settings.json with values from terraform output
az login
func start
```

## 🗑️ Cleanup

To delete all resources:

```bash
./cleanup.sh
```

**Warning**: This will permanently delete all resources and data!

## 📚 Additional Documentation

- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Detailed step-by-step guide
- [functions/README.md](functions/README.md) - Functions documentation
- [terraform/MANAGED-IDENTITY.md](terraform/MANAGED-IDENTITY.md) - Security documentation
- [terraform/function-code-examples.md](terraform/function-code-examples.md) - Code examples

## 💡 Common Commands

```bash
# View all Terraform outputs
cd terraform && terraform output

# Get specific output
cd terraform && terraform output -raw function_app_url

# Refresh Terraform state
cd terraform && terraform refresh

# Re-deploy functions after code changes
./deploy-functions.sh

# View function app settings
az functionapp config appsettings list \
  --name $(cd terraform && terraform output -raw function_app_name) \
  --resource-group $(cd terraform && terraform output -raw resource_group_name)
```

## 🎯 Next Steps

After successful deployment:

1. ✅ Configure Data Factory pipeline in Azure Portal
2. ✅ Set up blob event triggers
3. ✅ Test end-to-end invoice processing
4. ✅ Configure monitoring and alerts
5. ✅ Review security settings

For detailed instructions, see [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md).
