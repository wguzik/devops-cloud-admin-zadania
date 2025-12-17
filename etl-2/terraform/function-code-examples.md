# Function App Code Examples - Using Managed Identity

This document provides code examples for using Managed Identity in the Azure Function App.

## 📦 Required Python Packages

Add these to your `requirements.txt`:

```txt
azure-functions
azure-identity
azure-storage-blob
azure-ai-formrecognizer
pyodbc
```

## 🔐 Managed Identity Authentication

### 1. Connecting to Blob Storage

```python
import os
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
import azure.functions as func

def get_blob_service_client():
    """Get BlobServiceClient using Managed Identity"""
    account_name = os.environ["STORAGE_ACCOUNT_NAME"]
    account_url = f"https://{account_name}.blob.core.windows.net"
    
    credential = DefaultAzureCredential()
    blob_service_client = BlobServiceClient(account_url, credential=credential)
    
    return blob_service_client

def upload_invoice_example(req: func.HttpRequest) -> func.HttpResponse:
    """Example: Upload invoice using Managed Identity"""
    try:
        invoice_file = req.files.get('invoice')
        if not invoice_file:
            return func.HttpResponse("No file provided", status_code=400)
        
        # Get blob client with Managed Identity
        blob_service_client = get_blob_service_client()
        container_client = blob_service_client.get_container_client("raw-invoices")
        
        # Upload file
        blob_name = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{invoice_file.filename}"
        blob_client = container_client.get_blob_client(blob_name)
        blob_client.upload_blob(invoice_file.read())
        
        return func.HttpResponse(
            json.dumps({"status": "success", "blob_name": blob_name}),
            status_code=200,
            mimetype="application/json"
        )
    except Exception as e:
        logging.error(f"Error: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500
        )
```

### 2. Connecting to AI Document Intelligence

```python
import os
from azure.identity import DefaultAzureCredential
from azure.ai.formrecognizer import DocumentAnalysisClient
import azure.functions as func

def get_document_client():
    """Get DocumentAnalysisClient using Managed Identity"""
    endpoint = os.environ["FORM_RECOGNIZER_ENDPOINT"]
    credential = DefaultAzureCredential()
    
    document_client = DocumentAnalysisClient(
        endpoint=endpoint,
        credential=credential
    )
    
    return document_client

def analyze_invoice_example(blob_url: str) -> dict:
    """Example: Analyze invoice using Managed Identity"""
    try:
        document_client = get_document_client()
        
        # Analyze with prebuilt invoice model
        poller = document_client.begin_analyze_document_from_url(
            "prebuilt-invoice",
            blob_url
        )
        result = poller.result()
        
        invoice_data = {
            "receiver": None,
            "cost": None,
            "date": None,
            "invoice_id": None
        }
        
        for document in result.documents:
            fields = document.fields
            
            if "CustomerName" in fields:
                invoice_data["receiver"] = fields["CustomerName"].value
            
            if "InvoiceTotal" in fields:
                invoice_data["cost"] = fields["InvoiceTotal"].value
            
            if "InvoiceDate" in fields:
                invoice_data["date"] = fields["InvoiceDate"].value
            
            if "InvoiceId" in fields:
                invoice_data["invoice_id"] = fields["InvoiceId"].value
        
        return invoice_data
        
    except Exception as e:
        logging.error(f"Error analyzing invoice: {str(e)}")
        raise
```

### 3. Connecting to SQL Database

```python
import os
import pyodbc
from azure.identity import DefaultAzureCredential
import struct

def get_sql_connection():
    """Get SQL connection using Managed Identity"""
    server = os.environ["SQL_SERVER_FQDN"]
    database = os.environ["SQL_DATABASE_NAME"]
    
    # Get access token for SQL Database
    credential = DefaultAzureCredential()
    token = credential.get_token("https://database.windows.net/.default")
    
    # Convert token to format expected by ODBC driver
    token_bytes = token.token.encode("utf-16-le")
    token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)
    
    # Connection string with Managed Identity
    connection_string = (
        f"Driver={{ODBC Driver 18 for SQL Server}};"
        f"Server=tcp:{server},1433;"
        f"Database={database};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=no;"
        f"Connection Timeout=30"
    )
    
    # SQL_COPT_SS_ACCESS_TOKEN = 1256
    conn = pyodbc.connect(connection_string, attrs_before={1256: token_struct})
    
    return conn

def save_invoice_to_db_example(invoice_data: dict, blob_path: str):
    """Example: Save invoice data to SQL using Managed Identity"""
    try:
        conn = get_sql_connection()
        cursor = conn.cursor()
        
        sql = """
            INSERT INTO Invoices (
                InvoiceNumber, 
                Receiver, 
                Cost, 
                InvoiceDate, 
                BlobPath, 
                ValidationStatus
            )
            VALUES (?, ?, ?, ?, ?, ?)
        """
        
        cursor.execute(sql, (
            invoice_data.get("invoice_id"),
            invoice_data.get("receiver"),
            invoice_data.get("cost"),
            invoice_data.get("date"),
            blob_path,
            "processed"
        ))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        logging.info(f"Invoice saved successfully: {invoice_data.get('invoice_id')}")
        
    except Exception as e:
        logging.error(f"Error saving to database: {str(e)}")
        raise
```

### 4. Complete Function Example

```python
import logging
import json
import os
from datetime import datetime
import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
from azure.ai.formrecognizer import DocumentAnalysisClient
import pyodbc
import struct

def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Complete invoice processing function using Managed Identity
    """
    logging.info('Invoice processing function triggered')
    
    try:
        # 1. Get invoice file from request
        invoice_file = req.files.get('invoice')
        if not invoice_file:
            return func.HttpResponse(
                json.dumps({"error": "No file provided"}),
                status_code=400
            )
        
        # 2. Upload to Blob Storage (using Managed Identity)
        account_name = os.environ["STORAGE_ACCOUNT_NAME"]
        account_url = f"https://{account_name}.blob.core.windows.net"
        credential = DefaultAzureCredential()
        
        blob_service_client = BlobServiceClient(account_url, credential=credential)
        container_client = blob_service_client.get_container_client("raw-invoices")
        
        blob_name = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{invoice_file.filename}"
        blob_client = container_client.get_blob_client(blob_name)
        blob_client.upload_blob(invoice_file.read())
        blob_url = blob_client.url
        
        # 3. Analyze invoice with AI Document Intelligence (using Managed Identity)
        endpoint = os.environ["FORM_RECOGNIZER_ENDPOINT"]
        document_client = DocumentAnalysisClient(endpoint=endpoint, credential=credential)
        
        poller = document_client.begin_analyze_document_from_url("prebuilt-invoice", blob_url)
        result = poller.result()
        
        # Extract invoice data
        invoice_data = {}
        for document in result.documents:
            fields = document.fields
            invoice_data = {
                "invoice_id": fields.get("InvoiceId").value if "InvoiceId" in fields else None,
                "receiver": fields.get("CustomerName").value if "CustomerName" in fields else None,
                "cost": fields.get("InvoiceTotal").value if "InvoiceTotal" in fields else None,
                "date": fields.get("InvoiceDate").value if "InvoiceDate" in fields else None
            }
        
        # 4. Save to SQL Database (using Managed Identity)
        server = os.environ["SQL_SERVER_FQDN"]
        database = os.environ["SQL_DATABASE_NAME"]
        
        token = credential.get_token("https://database.windows.net/.default")
        token_bytes = token.token.encode("utf-16-le")
        token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)
        
        connection_string = (
            f"Driver={{ODBC Driver 18 for SQL Server}};"
            f"Server=tcp:{server},1433;"
            f"Database={database};"
            f"Encrypt=yes;"
            f"TrustServerCertificate=no;"
        )
        
        conn = pyodbc.connect(connection_string, attrs_before={1256: token_struct})
        cursor = conn.cursor()
        
        sql = """
            INSERT INTO Invoices (InvoiceNumber, Receiver, Cost, InvoiceDate, BlobPath, ValidationStatus)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        
        cursor.execute(sql, (
            invoice_data.get("invoice_id"),
            invoice_data.get("receiver"),
            invoice_data.get("cost"),
            invoice_data.get("date"),
            blob_name,
            "processed"
        ))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        return func.HttpResponse(
            json.dumps({
                "status": "success",
                "blob_name": blob_name,
                "invoice_data": invoice_data
            }),
            status_code=200,
            mimetype="application/json"
        )
        
    except Exception as e:
        logging.error(f"Error processing invoice: {str(e)}")
        return func.HttpResponse(
            json.dumps({"error": str(e)}),
            status_code=500
        )
```

## 🔍 Testing Locally

For local development, ensure you're logged in with Azure CLI:

```bash
az login
az account set --subscription "<your-subscription-id>"
```

The `DefaultAzureCredential()` will automatically use your Azure CLI credentials locally and Managed Identity when deployed to Azure.

## 📚 Additional Resources

- [Azure Identity SDK for Python](https://docs.microsoft.com/python/api/overview/azure/identity-readme)
- [Azure Blob Storage SDK](https://docs.microsoft.com/python/api/overview/azure/storage-blob-readme)
- [Azure AI Document Intelligence SDK](https://docs.microsoft.com/python/api/overview/azure/ai-formrecognizer-readme)
- [Connect to SQL with Managed Identity](https://docs.microsoft.com/azure/app-service/tutorial-connect-msi-sql-database)
