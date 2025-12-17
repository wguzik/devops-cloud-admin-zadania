#!/bin/bash

# Deploy Azure Functions to Azure
# This script deploys the invoice processing functions to the Azure Function App
# created by Terraform

set -e

echo "=================================="
echo "Azure Functions Deployment Script"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "terraform/main.tf" ]; then
    echo -e "${RED}Error: This script must be run from the etl-2 directory${NC}"
    echo "Current directory: $(pwd)"
    exit 1
fi

# Check if terraform state exists
if [ ! -f "terraform/terraform.tfstate" ]; then
    echo -e "${RED}Error: Terraform state not found. Please run 'terraform apply' first.${NC}"
    exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed.${NC}"
    echo "Please install it from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

# Check if Azure Functions Core Tools is installed
if ! command -v func &> /dev/null; then
    echo -e "${RED}Error: Azure Functions Core Tools is not installed.${NC}"
    echo "Please install it from: https://docs.microsoft.com/azure/azure-functions/functions-run-local"
    exit 1
fi

# Check if logged in to Azure
echo "Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Not logged in to Azure. Please login:${NC}"
    az login
fi

echo ""
echo "Getting deployment information from Terraform..."

# Get values from Terraform outputs
cd terraform
FUNCTION_APP_NAME=$(terraform output -raw function_app_name 2>/dev/null || echo "")
RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")

if [ -z "$FUNCTION_APP_NAME" ] || [ -z "$RESOURCE_GROUP" ]; then
    echo -e "${RED}Error: Could not retrieve Function App name or Resource Group from Terraform.${NC}"
    echo "Please ensure Terraform has been applied successfully."
    exit 1
fi

echo ""
echo -e "${GREEN}Deployment Configuration:${NC}"
echo "  Resource Group:  $RESOURCE_GROUP"
echo "  Function App:    $FUNCTION_APP_NAME"
echo ""

# Go to functions directory
cd ../functions

# Check if functions directory exists and has content
if [ ! -f "host.json" ]; then
    echo -e "${RED}Error: Functions directory is not properly configured.${NC}"
    echo "Missing host.json file."
    exit 1
fi

# Confirm deployment
echo -e "${YELLOW}Ready to deploy functions to Azure.${NC}"
read -p "Continue with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "=================================="
echo "Starting deployment..."
echo "=================================="
echo ""

# Deploy the function app
echo "Deploying functions to $FUNCTION_APP_NAME..."
func azure functionapp publish $FUNCTION_APP_NAME --python

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=================================="
    echo "Deployment Successful!"
    echo "==================================${NC}"
    echo ""
    echo "Function App URL: https://${FUNCTION_APP_NAME}.azurewebsites.net"
    echo ""
    echo "Available functions:"
    echo "  - InvoiceUpload"
    echo "  - ValidateInvoice"
    echo "  - ExtractInvoiceData"
    echo ""
    echo "To get function keys, run:"
    echo "  az functionapp keys list --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP"
    echo ""
    echo "To view logs:"
    echo "  az functionapp log tail --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP"
    echo ""
else
    echo -e "${RED}=================================="
    echo "Deployment Failed!"
    echo "==================================${NC}"
    echo ""
    echo "Please check the error messages above and try again."
    exit 1
fi
