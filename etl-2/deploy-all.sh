#!/bin/bash

# Complete Infrastructure and Application Deployment
# This script orchestrates the full deployment: Terraform → SQL Setup → Functions

set -e

echo "========================================================"
echo "Invoice ETL - Complete Infrastructure Deployment"
echo "========================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"
echo ""

MISSING_TOOLS=()

if ! command -v terraform &> /dev/null; then
    MISSING_TOOLS+=("terraform")
fi

if ! command -v az &> /dev/null; then
    MISSING_TOOLS+=("azure-cli")
fi

if ! command -v func &> /dev/null; then
    MISSING_TOOLS+=("azure-functions-core-tools")
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo -e "${RED}Error: Missing required tools:${NC}"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  - $tool"
    done
    echo ""
    echo "Please install missing tools and try again."
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# Check Azure login
echo -e "${BLUE}Step 2: Verifying Azure authentication...${NC}"
echo ""

if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Not logged in to Azure. Please login:${NC}"
    az login
fi

# Get current subscription
CURRENT_SUB_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
SUBSCRIPTION=$(az account show --query name -o tsv 2>/dev/null || echo "")

# Verify subscription is in enabled list
# Navigate to terraform directory
cd terraform

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Warning: terraform.tfvars not found.${NC}"
    echo "Please create terraform.tfvars from terraform.tfvars.example and configure it."
    echo ""
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Terraform Init
# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Warning: terraform.tfvars not found.${NC}"
    echo "Please create terraform.tfvars from terraform.tfvars.example and configure it."
    echo ""
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Replace 'abc-abc' with current subscription ID in terraform.tfvars
if [ -f "terraform.tfvars" ]; then
    CURRENT_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    if [ -n "$CURRENT_SUBSCRIPTION_ID" ]; then
        echo "Updating subscription ID in terraform.tfvars..."
        sed -i.bak "s/abc-abc/$CURRENT_SUBSCRIPTION_ID/g" terraform.tfvars
        echo -e "${GREEN}✓ Subscription ID updated to: $CURRENT_SUBSCRIPTION_ID${NC}"
        echo ""
    fi
fi

# Terraform Init
echo -e "${BLUE}Step 3: Initializing Terraform...${NC}"
echo ""
terraform init

if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform init failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Terraform Plan
echo -e "${BLUE}Step 4: Creating Terraform plan...${NC}"
echo ""
terraform plan -out=tfplan

if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform plan failed!${NC}"
    exit 1
fi

echo ""
read -p "Do you want to apply this plan? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    rm -f tfplan
    exit 0
fi

# Terraform Apply
echo ""
echo -e "${BLUE}Step 5: Deploying infrastructure with Terraform...${NC}"
echo ""
terraform apply tfplan

if [ $? -ne 0 ]; then
    echo -e "${RED}Terraform apply failed!${NC}"
    exit 1
fi

rm -f tfplan

echo ""
echo -e "${GREEN}✓ Infrastructure deployed successfully${NC}"
echo ""

# Wait for resources to be fully ready
echo -e "${YELLOW}Waiting 30 seconds for resources to be fully ready...${NC}"
sleep 30

# SQL Database Setup
echo ""
echo -e "${BLUE}Step 6: Configuring SQL Database access...${NC}"
echo ""

if [ -f "setup-sql-managed-identity.sh" ]; then
    chmod +x setup-sql-managed-identity.sh
    ./setup-sql-managed-identity.sh
    
    echo ""
    echo -e "${YELLOW}Please execute the generated SQL script to grant managed identity access.${NC}"
    echo ""
    read -p "Have you executed the SQL script? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Warning: SQL setup incomplete. Functions may fail to access database.${NC}"
        echo "You can run the SQL script later: ./terraform/configure-managed-identities.sql"
    fi
else
    echo -e "${YELLOW}SQL setup script not found. Please configure SQL manually.${NC}"
fi

# Deploy Functions
echo ""
echo -e "${BLUE}Step 7: Deploying Azure Functions...${NC}"
echo ""

cd ..
chmod +x deploy-functions.sh
./deploy-functions.sh

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================================"
    echo "Deployment Complete!"
    echo "========================================================${NC}"
    echo ""
    
    cd terraform
    
    echo "Deployment Summary:"
    echo ""
    echo "Resource Group:    $(terraform output -raw resource_group_name)"
    echo "Function App:      $(terraform output -raw function_app_name)"
    echo "Function App URL:  $(terraform output -raw function_app_url)"
    echo "SQL Server:        $(terraform output -raw sql_server_fqdn)"
    echo "SQL Database:      $(terraform output -raw sql_database_name)"
    echo "Storage Account:   $(terraform output -raw storage_account_name)"
    echo ""
    
    echo "Next Steps:"
    echo ""
    echo "1. Test the functions:"
    echo "   ./test-functions.sh"
    echo ""
    echo "2. Configure Data Factory pipeline in Azure Portal"
    echo ""
    echo "3. Monitor function logs:"
    echo "   az functionapp log tail --name $(terraform output -raw function_app_name) --resource-group $(terraform output -raw resource_group_name)"
    echo ""
    echo "4. View deployment guide:"
    echo "   cat ../DEPLOYMENT-GUIDE.md"
    echo ""
else
    echo -e "${RED}Function deployment failed. Please check errors above.${NC}"
    exit 1
fi
