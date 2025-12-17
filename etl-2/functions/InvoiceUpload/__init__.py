import logging
import json
import os
from datetime import datetime
import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    HTTP Trigger function to upload invoice files to blob storage.
    Uses Managed Identity for authentication.
    """
    logging.info('Invoice upload function triggered')
    
    try:
        # Get invoice file from request
        invoice_file = req.files.get('invoice')
        if not invoice_file:
            return func.HttpResponse(
                json.dumps({"error": "No file provided. Use 'invoice' as the file field name."}),
                status_code=400,
                mimetype="application/json"
            )
        
        # Upload to Blob Storage using Managed Identity
        account_name = os.environ["STORAGE_ACCOUNT_NAME"]
        account_url = f"https://{account_name}.blob.core.windows.net"
        credential = DefaultAzureCredential()
        
        blob_service_client = BlobServiceClient(account_url, credential=credential)
        container_client = blob_service_client.get_container_client("raw-invoices")
        
        # Generate unique blob name with timestamp
        blob_name = f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{invoice_file.filename}"
        blob_client = container_client.get_blob_client(blob_name)
        
        # Upload the file
        blob_client.upload_blob(invoice_file.read(), overwrite=False)
        blob_url = blob_client.url
        
        logging.info(f"Successfully uploaded invoice: {blob_name}")
        
        return func.HttpResponse(
            json.dumps({
                "status": "success",
                "blob_name": blob_name,
                "blob_url": blob_url,
                "message": "Invoice uploaded successfully to raw-invoices container"
            }),
            status_code=200,
            mimetype="application/json"
        )
        
    except Exception as e:
        logging.error(f"Error uploading invoice: {str(e)}")
        return func.HttpResponse(
            json.dumps({
                "error": str(e),
                "message": "Failed to upload invoice"
            }),
            status_code=500,
            mimetype="application/json"
        )
