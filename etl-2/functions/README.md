# Invoice Processing Azure Functions

This directory contains Azure Functions for the Invoice ETL pipeline.

## Functions

### 1. InvoiceUpload
- **Type**: HTTP Trigger
- **Purpose**: Upload invoice files to blob storage
- **Method**: POST
- **Input**: Multipart form data with 'invoice' file field
- **Authentication**: Managed Identity to Blob Storage

### 2. ValidateInvoice
- **Type**: HTTP Trigger
- **Purpose**: Validate uploaded invoices using AI Document Intelligence
- **Method**: POST
- **Input**: JSON with `blob_url`
- **Authentication**: Managed Identity to AI Document Intelligence

### 3. ExtractInvoiceData
- **Type**: HTTP Trigger
- **Purpose**: Extract invoice data and save to SQL Database
- **Method**: POST
- **Input**: JSON with `blob_url` and optional `blob_name`
- **Authentication**: Managed Identity to AI Document Intelligence and SQL Database

## Local Development

### Prerequisites

1. Python 3.9 or higher
2. Azure Functions Core Tools
3. Azure CLI (logged in)

### Setup

1. Create a virtual environment:
```bash
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Copy local settings:
```bash
cp local.settings.json.example local.settings.json
```

4. Update `local.settings.json` with your values (get from Terraform outputs)

5. Login to Azure:
```bash
az login
az account set --subscription "<your-subscription-id>"
```

### Run Locally

```bash
func start
```

The functions will be available at:
- InvoiceUpload: http://localhost:7071/api/InvoiceUpload
- ValidateInvoice: http://localhost:7071/api/ValidateInvoice
- ExtractInvoiceData: http://localhost:7071/api/ExtractInvoiceData

### Test Locally

Upload an invoice:
```bash
curl -X POST http://localhost:7071/api/InvoiceUpload \
  -F "invoice=@path/to/test-invoice.pdf"
```

Validate an invoice:
```bash
curl -X POST http://localhost:7071/api/ValidateInvoice \
  -H "Content-Type: application/json" \
  -d '{"blob_url": "https://yourstore.blob.core.windows.net/raw-invoices/invoice.pdf"}'
```

Extract invoice data:
```bash
curl -X POST http://localhost:7071/api/ExtractInvoiceData \
  -H "Content-Type: application/json" \
  -d '{"blob_url": "https://yourstore.blob.core.windows.net/raw-invoices/invoice.pdf", "blob_name": "invoice.pdf"}'
```

## Deployment

Use the deployment script in the parent directory:
```bash
cd ..
./deploy-functions.sh
```

Or deploy manually:
```bash
# Get function app name from Terraform
cd ../terraform
FUNCTION_APP_NAME=$(terraform output -raw function_app_name)
RESOURCE_GROUP=$(terraform output -raw resource_group_name)

# Deploy
cd ../functions
func azure functionapp publish $FUNCTION_APP_NAME
```

## Environment Variables

The following environment variables are automatically configured via Terraform:

- `STORAGE_ACCOUNT_NAME`: Name of the storage account for invoices
- `FORM_RECOGNIZER_ENDPOINT`: Endpoint for AI Document Intelligence
- `SQL_SERVER_FQDN`: Fully qualified domain name of SQL Server
- `SQL_DATABASE_NAME`: Name of the SQL database
- `FUNCTIONS_WORKER_RUNTIME`: Set to "python"
- `AzureWebJobsStorage__accountName`: Storage account for function internals

## Managed Identity

All functions use Azure Managed Identity for authentication:
- No connection strings or keys in code
- Automatic credential handling via `DefaultAzureCredential()`
- Permissions configured via Terraform role assignments

## Troubleshooting

### Authentication Errors

Ensure you're logged in with Azure CLI for local development:
```bash
az login
az account show
```

### Missing Dependencies

Install/update dependencies:
```bash
pip install -r requirements.txt --upgrade
```

### Connection Errors

Verify environment variables are set correctly in `local.settings.json` for local development, or check Azure Portal → Function App → Configuration for deployed functions.
