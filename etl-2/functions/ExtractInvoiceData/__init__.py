import logging
import json
import os
from datetime import datetime
import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.ai.formrecognizer import DocumentAnalysisClient
from azure.storage.blob import BlobServiceClient
import pyodbc
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


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Extract invoice data using AI Document Intelligence and save to SQL Database.
    Uses Managed Identity for all connections.
    """
    logging.info('Invoice data extraction function triggered')
    
    try:
        # Get blob URL from request
        req_body = req.get_json()
        blob_url = req_body.get('blob_url')
        blob_name = req_body.get('blob_name', '')
        
        if not blob_url:
            return func.HttpResponse(
                json.dumps({"error": "blob_url parameter is required"}),
                status_code=400,
                mimetype="application/json"
            )
        
        # Initialize Azure AI Document Intelligence with Managed Identity
        endpoint = os.environ["FORM_RECOGNIZER_ENDPOINT"]
        credential = DefaultAzureCredential()
        
        document_client = DocumentAnalysisClient(
            endpoint=endpoint,
            credential=credential
        )
        
        # Analyze document with prebuilt invoice model
        logging.info(f"Extracting data from document: {blob_url}")
        poller = document_client.begin_analyze_document_from_url(
            "prebuilt-invoice", 
            blob_url
        )
        result = poller.result()
        
        # Extract invoice data
        invoice_data = {
            "invoice_id": None,
            "receiver": None,
            "cost": None,
            "date": None,
            "vendor": None,
            "subtotal": None,
            "tax": None
        }
        
        if result.documents:
            document = result.documents[0]
            fields = document.fields
            
            # Extract required fields
            if "InvoiceId" in fields and fields["InvoiceId"].value:
                invoice_data["invoice_id"] = str(fields["InvoiceId"].value)
            
            if "CustomerName" in fields and fields["CustomerName"].value:
                invoice_data["receiver"] = str(fields["CustomerName"].value)
            
            if "VendorName" in fields and fields["VendorName"].value:
                invoice_data["vendor"] = str(fields["VendorName"].value)
            
            if "InvoiceTotal" in fields and fields["InvoiceTotal"].value:
                invoice_data["cost"] = float(fields["InvoiceTotal"].value.amount if hasattr(fields["InvoiceTotal"].value, 'amount') else fields["InvoiceTotal"].value)
            
            if "SubTotal" in fields and fields["SubTotal"].value:
                invoice_data["subtotal"] = float(fields["SubTotal"].value.amount if hasattr(fields["SubTotal"].value, 'amount') else fields["SubTotal"].value)
            
            if "TotalTax" in fields and fields["TotalTax"].value:
                invoice_data["tax"] = float(fields["TotalTax"].value.amount if hasattr(fields["TotalTax"].value, 'amount') else fields["TotalTax"].value)
            
            if "InvoiceDate" in fields and fields["InvoiceDate"].value:
                date_value = fields["InvoiceDate"].value
                if hasattr(date_value, 'strftime'):
                    invoice_data["date"] = date_value.strftime('%Y-%m-%d')
                else:
                    invoice_data["date"] = str(date_value)
            
            logging.info(f"Extracted invoice data: {invoice_data}")
        
        # Save to SQL Database using Managed Identity
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
                invoice_data.get("receiver") or invoice_data.get("vendor") or "Unknown",
                invoice_data.get("cost"),
                invoice_data.get("date"),
                blob_name,
                "processed"
            ))
            
            conn.commit()
            cursor.close()
            conn.close()
            
            logging.info(f"Invoice saved to database: {invoice_data.get('invoice_id')}")
            
        except Exception as db_error:
            logging.warning(f"Failed to save to database: {str(db_error)}")
            # Continue even if DB save fails
        
        return func.HttpResponse(
            json.dumps({
                "status": "success",
                "invoice_data": invoice_data,
                "blob_url": blob_url
            }),
            status_code=200,
            mimetype="application/json"
        )
        
    except Exception as e:
        logging.error(f"Error extracting invoice data: {str(e)}")
        return func.HttpResponse(
            json.dumps({
                "error": str(e),
                "message": "Error during data extraction"
            }),
            status_code=500,
            mimetype="application/json"
        )
