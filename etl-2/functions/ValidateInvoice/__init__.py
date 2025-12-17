import logging
import json
import os
import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.ai.formrecognizer import DocumentAnalysisClient


def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Validate if the uploaded file is a legitimate invoice.
    Uses Azure AI Document Intelligence with Managed Identity.
    """
    logging.info('Invoice validation function triggered')
    
    try:
        # Get blob URL from request
        req_body = req.get_json()
        blob_url = req_body.get('blob_url')
        
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
        logging.info(f"Analyzing document: {blob_url}")
        poller = document_client.begin_analyze_document_from_url(
            "prebuilt-invoice", 
            blob_url
        )
        result = poller.result()
        
        # Validation checks
        is_valid = True
        validation_errors = []
        document_type = None
        confidence = 0.0
        
        if not result.documents:
            is_valid = False
            validation_errors.append("No invoice detected in the document")
        else:
            document = result.documents[0]
            document_type = document.doc_type
            confidence = document.confidence
            
            # Check confidence score threshold
            if confidence < 0.7:
                is_valid = False
                validation_errors.append(f"Low confidence invoice detection: {confidence:.2f}")
            
            # Check if required fields exist
            required_fields = ["CustomerName", "InvoiceTotal", "InvoiceDate"]
            missing_fields = []
            
            for field_name in required_fields:
                if field_name not in document.fields or not document.fields[field_name].value:
                    missing_fields.append(field_name)
            
            if missing_fields:
                validation_errors.append(f"Missing required fields: {', '.join(missing_fields)}")
                if len(missing_fields) >= 2:
                    is_valid = False
        
        response_data = {
            "is_valid": is_valid,
            "confidence": confidence,
            "document_type": document_type,
            "validation_errors": validation_errors,
            "blob_url": blob_url
        }
        
        logging.info(f"Validation result: {'Valid' if is_valid else 'Invalid'}, Confidence: {confidence:.2f}")
        
        return func.HttpResponse(
            json.dumps(response_data),
            status_code=200,
            mimetype="application/json"
        )
        
    except Exception as e:
        logging.error(f"Error validating invoice: {str(e)}")
        return func.HttpResponse(
            json.dumps({
                "is_valid": False,
                "errors": [str(e)],
                "message": "Error during validation"
            }),
            status_code=500,
            mimetype="application/json"
        )
