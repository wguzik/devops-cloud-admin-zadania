#!/bin/bash

# Post-Deployment SQL Configuration Script
# This script helps configure SQL Database access for Managed Identities

set -e

echo "=================================="
echo "SQL Database Managed Identity Setup"
echo "=================================="
echo ""

# Check if terraform outputs are available
if [ ! -f "terraform.tfstate" ]; then
    echo "Error: terraform.tfstate not found. Please run 'terraform apply' first."
    exit 1
fi

# Get values from Terraform outputs
echo "Retrieving Terraform outputs..."
FUNCTION_APP_NAME=$(terraform output -raw function_app_name 2>/dev/null || echo "")
DATA_FACTORY_NAME=$(terraform output -raw data_factory_name 2>/dev/null || echo "")
SQL_SERVER=$(terraform output -raw sql_server_fqdn 2>/dev/null || echo "")
SQL_DATABASE=$(terraform output -raw sql_database_name 2>/dev/null || echo "")
RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")

if [ -z "$FUNCTION_APP_NAME" ] || [ -z "$DATA_FACTORY_NAME" ] || [ -z "$SQL_SERVER" ] || [ -z "$SQL_DATABASE" ]; then
    echo "Error: Could not retrieve required outputs from Terraform."
    exit 1
fi

echo ""
echo "Configuration Details:"
echo "  Function App:   $FUNCTION_APP_NAME"
echo "  Data Factory:   $DATA_FACTORY_NAME"
echo "  SQL Server:     $SQL_SERVER"
echo "  SQL Database:   $SQL_DATABASE"
echo "  Resource Group: $RESOURCE_GROUP"
echo ""

# Create SQL file with the commands
SQL_FILE="configure-managed-identities.sql"
echo "Creating SQL script: $SQL_FILE"

cat > "$SQL_FILE" << EOF
-- Configure Managed Identity Access for Invoice ETL
-- Generated: $(date)

-- Create user for Function App Managed Identity
PRINT 'Creating user for Function App...';
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'${FUNCTION_APP_NAME}')
BEGIN
    CREATE USER [${FUNCTION_APP_NAME}] FROM EXTERNAL PROVIDER;
    PRINT 'User [${FUNCTION_APP_NAME}] created successfully.';
END
ELSE
BEGIN
    PRINT 'User [${FUNCTION_APP_NAME}] already exists.';
END
GO

-- Grant permissions to Function App
PRINT 'Granting permissions to Function App...';
ALTER ROLE db_datareader ADD MEMBER [${FUNCTION_APP_NAME}];
ALTER ROLE db_datawriter ADD MEMBER [${FUNCTION_APP_NAME}];
PRINT 'Permissions granted to [${FUNCTION_APP_NAME}].';
GO

-- Create user for Data Factory Managed Identity
PRINT 'Creating user for Data Factory...';
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'${DATA_FACTORY_NAME}')
BEGIN
    CREATE USER [${DATA_FACTORY_NAME}] FROM EXTERNAL PROVIDER;
    PRINT 'User [${DATA_FACTORY_NAME}] created successfully.';
END
ELSE
BEGIN
    PRINT 'User [${DATA_FACTORY_NAME}] already exists.';
END
GO

-- Grant permissions to Data Factory
PRINT 'Granting permissions to Data Factory...';
ALTER ROLE db_datareader ADD MEMBER [${DATA_FACTORY_NAME}];
ALTER ROLE db_datawriter ADD MEMBER [${DATA_FACTORY_NAME}];
PRINT 'Permissions granted to [${DATA_FACTORY_NAME}].';
GO

-- Create Invoices table
PRINT 'Creating Invoices table...';
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Invoices')
BEGIN
    CREATE TABLE Invoices (
        InvoiceID INT IDENTITY(1,1) PRIMARY KEY,
        InvoiceNumber NVARCHAR(100),
        Receiver NVARCHAR(255) NOT NULL,
        Cost DECIMAL(18, 2) NOT NULL,
        InvoiceDate DATE NOT NULL,
        ProcessedDate DATETIME DEFAULT GETDATE(),
        BlobPath NVARCHAR(500),
        ValidationStatus NVARCHAR(50),
        CreatedAt DATETIME DEFAULT GETDATE()
    );
    PRINT 'Invoices table created.';
    
    CREATE INDEX IDX_InvoiceDate ON Invoices(InvoiceDate);
    CREATE INDEX IDX_Receiver ON Invoices(Receiver);
    PRINT 'Indexes created.';
END
ELSE
BEGIN
    PRINT 'Invoices table already exists.';
END
GO

-- Verify configuration
PRINT 'Verifying managed identity users...';
SELECT 
    name AS UserName,
    type_desc AS UserType,
    create_date AS CreatedDate
FROM sys.database_principals 
WHERE name IN ('${FUNCTION_APP_NAME}', '${DATA_FACTORY_NAME}')
ORDER BY name;
GO

PRINT 'Verifying role memberships...';
SELECT 
    dp.name AS UserName,
    drp.name AS RoleName
FROM sys.database_principals dp
INNER JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
INNER JOIN sys.database_principals drp ON drm.role_principal_id = drp.principal_id
WHERE dp.name IN ('${FUNCTION_APP_NAME}', '${DATA_FACTORY_NAME}')
ORDER BY dp.name, drp.name;
GO

PRINT 'Configuration complete!';
EOF

echo "SQL script created successfully!"
echo ""
echo "=================================="
echo "Next Steps:"
echo "=================================="
echo ""
echo "Option 1: Execute using sqlcmd (requires Azure CLI login)"
echo "  az login"
echo "  sqlcmd -S $SQL_SERVER -d $SQL_DATABASE -G -i $SQL_FILE"
echo ""
echo "Option 2: Execute using Azure Data Studio or SSMS"
echo "  1. Connect to: $SQL_SERVER"
echo "  2. Database: $SQL_DATABASE"
echo "  3. Authentication: Azure Active Directory - Universal with MFA"
echo "  4. Open and execute: $SQL_FILE"
echo ""
echo "Option 3: Use Azure Portal Query Editor"
echo "  1. Navigate to: https://portal.azure.com"
echo "  2. Open SQL Database: $SQL_DATABASE"
echo "  3. Go to 'Query editor' and authenticate with Azure AD"
echo "  4. Copy and paste contents of: $SQL_FILE"
echo ""

# Offer to verify role assignments
echo "=================================="
echo "Verify Role Assignments (optional)"
echo "=================================="
echo ""
read -p "Do you want to verify Azure role assignments now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Function App Role Assignments:"
    FUNCTION_APP_ID=$(az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" --query identity.principalId -o tsv 2>/dev/null || echo "")
    if [ -n "$FUNCTION_APP_ID" ]; then
        az role assignment list --assignee "$FUNCTION_APP_ID" --all -o table
    else
        echo "Could not retrieve Function App identity."
    fi
    
    echo ""
    echo "Data Factory Role Assignments:"
    ADF_ID=$(az datafactory show --name "$DATA_FACTORY_NAME" --resource-group "$RESOURCE_GROUP" --query identity.principalId -o tsv 2>/dev/null || echo "")
    if [ -n "$ADF_ID" ]; then
        az role assignment list --assignee "$ADF_ID" --all -o table
    else
        echo "Could not retrieve Data Factory identity."
    fi
fi

echo ""
echo "Setup preparation complete!"
