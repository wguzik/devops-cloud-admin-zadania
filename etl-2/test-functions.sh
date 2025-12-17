#!/bin/bash

# Test Azure Functions
# This script tests the deployed Azure Functions

set -e

echo "=================================="
echo "Testing Azure Functions"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if terraform state exists
if [ ! -f "terraform/terraform.tfstate" ]; then
    echo -e "${RED}Error: Terraform state not found.${NC}"
    echo "Please deploy infrastructure first: ./deploy-all.sh"
    exit 1
fi

# Get values from Terraform
cd terraform
FUNCTION_APP_NAME=$(terraform output -raw function_app_name 2>/dev/null || echo "")
RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
FUNCTION_URL=$(terraform output -raw function_app_url 2>/dev/null || echo "")

if [ -z "$FUNCTION_APP_NAME" ]; then
    echo -e "${RED}Error: Could not retrieve Function App information from Terraform.${NC}"
    exit 1
fi

cd ..

echo "Function App: $FUNCTION_APP_NAME"
echo "Function URL: $FUNCTION_URL"
echo ""

# Get function key
echo "Retrieving function key..."
FUNCTION_KEY=$(az functionapp keys list \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "functionKeys.default" -o tsv 2>/dev/null)

if [ -z "$FUNCTION_KEY" ]; then
    echo -e "${RED}Error: Could not retrieve function key.${NC}"
    echo "Please ensure you have access to the Function App."
    exit 1
fi

echo -e "${GREEN}✓ Function key retrieved${NC}"
echo ""

# Test InvoiceUpload function
echo "Testing InvoiceUpload function..."
echo ""

# Check if test file exists
if [ ! -f "test-invoice.pdf" ] && [ ! -f "test-invoice.jpg" ]; then
    echo -e "${YELLOW}No test invoice file found (test-invoice.pdf or test-invoice.jpg)${NC}"
    echo "Creating a dummy test file..."
    echo "This is a test invoice file" > test-invoice.txt
    TEST_FILE="test-invoice.txt"
else
    if [ -f "test-invoice.pdf" ]; then
        TEST_FILE="test-invoice.pdf"
    else
        TEST_FILE="test-invoice.jpg"
    fi
fi

echo "Uploading test file: $TEST_FILE"
echo ""

UPLOAD_RESPONSE=$(curl -s -X POST \
    "${FUNCTION_URL}/api/InvoiceUpload?code=${FUNCTION_KEY}" \
    -F "invoice=@${TEST_FILE}" \
    -H "Accept: application/json")

echo "Response:"
echo "$UPLOAD_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$UPLOAD_RESPONSE"
echo ""

# Check if upload was successful
if echo "$UPLOAD_RESPONSE" | grep -q '"status": "success"'; then
    echo -e "${GREEN}✓ InvoiceUpload test passed${NC}"
    
    # Extract blob_url from response
    BLOB_URL=$(echo "$UPLOAD_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('blob_url', ''))" 2>/dev/null || echo "")
    BLOB_NAME=$(echo "$UPLOAD_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('blob_name', ''))" 2>/dev/null || echo "")
    
    if [ -n "$BLOB_URL" ]; then
        echo ""
        echo "Testing ValidateInvoice function..."
        echo ""
        
        VALIDATE_RESPONSE=$(curl -s -X POST \
            "${FUNCTION_URL}/api/ValidateInvoice?code=${FUNCTION_KEY}" \
            -H "Content-Type: application/json" \
            -d "{\"blob_url\": \"${BLOB_URL}\"}")
        
        echo "Response:"
        echo "$VALIDATE_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$VALIDATE_RESPONSE"
        echo ""
        
        if echo "$VALIDATE_RESPONSE" | grep -q '"is_valid"'; then
            echo -e "${GREEN}✓ ValidateInvoice test completed${NC}"
        else
            echo -e "${YELLOW}⚠ ValidateInvoice test completed with warnings${NC}"
        fi
        
        echo ""
        echo "Testing ExtractInvoiceData function..."
        echo ""
        
        EXTRACT_RESPONSE=$(curl -s -X POST \
            "${FUNCTION_URL}/api/ExtractInvoiceData?code=${FUNCTION_KEY}" \
            -H "Content-Type: application/json" \
            -d "{\"blob_url\": \"${BLOB_URL}\", \"blob_name\": \"${BLOB_NAME}\"}")
        
        echo "Response:"
        echo "$EXTRACT_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$EXTRACT_RESPONSE"
        echo ""
        
        if echo "$EXTRACT_RESPONSE" | grep -q '"invoice_data"'; then
            echo -e "${GREEN}✓ ExtractInvoiceData test completed${NC}"
        else
            echo -e "${YELLOW}⚠ ExtractInvoiceData test completed with warnings${NC}"
        fi
    fi
else
    echo -e "${RED}✗ InvoiceUpload test failed${NC}"
fi

echo ""
echo "=================================="
echo "Test Summary"
echo "=================================="
echo ""
echo "Function endpoints:"
echo "  InvoiceUpload:      ${FUNCTION_URL}/api/InvoiceUpload"
echo "  ValidateInvoice:    ${FUNCTION_URL}/api/ValidateInvoice"
echo "  ExtractInvoiceData: ${FUNCTION_URL}/api/ExtractInvoiceData"
echo ""
echo "To upload a real invoice:"
echo "  curl -X POST '${FUNCTION_URL}/api/InvoiceUpload?code=${FUNCTION_KEY}' \\"
echo "    -F 'invoice=@path/to/your-invoice.pdf'"
echo ""
echo "To view function logs:"
echo "  az functionapp log tail --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP"
echo ""
