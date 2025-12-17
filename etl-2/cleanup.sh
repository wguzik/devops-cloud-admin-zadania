#!/bin/bash

# Cleanup and destroy all resources
# WARNING: This will delete all resources created by Terraform

set -e

echo "========================================================"
echo "Invoice ETL - Resource Cleanup"
echo "========================================================"
echo ""

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}WARNING: This will destroy all resources including:${NC}"
echo "  - Function App and all deployed functions"
echo "  - Storage Accounts and all stored data"
echo "  - SQL Server and Database (all invoice data will be lost)"
echo "  - AI Document Intelligence service"
echo "  - Data Factory and pipelines"
echo "  - All role assignments and configurations"
echo ""
echo -e "${RED}This action CANNOT be undone!${NC}"
echo ""

read -p "Are you sure you want to continue? Type 'yes' to confirm: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
read -p "Really destroy all resources? Type 'DELETE' to confirm: " CONFIRM2

if [ "$CONFIRM2" != "DELETE" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

cd terraform

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}No Terraform state found. Nothing to destroy.${NC}"
    exit 0
fi

# Run terraform destroy
terraform destroy

echo ""
echo "========================================================"
echo "Cleanup Complete"
echo "========================================================"
echo ""
echo "All resources have been destroyed."
echo ""
