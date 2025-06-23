#!/bin/bash
# This script is used to set up the Azure resources for the project.
# Be sure  to update the resource group name.

resourceGroup=rg-exercises
location=eastus
accountName=storageacct$RANDOM

# Create a Cosmos account
echo "Creating Azure Storage account, can take a few minutes..."
az storage account create --name $accountName \
    --resource-group $resourceGroup \
    --location $location \
    --sku Standard_LRS 

# Add needed role for the user
userPrincipal=$(az rest --method GET --url https://graph.microsoft.com/v1.0/me \
    --headers 'Content-Type=application/json' \
    --query userPrincipalName --output tsv)

resourceID=$(az storage account show \
    --name $accountName \
    --resource-group $resourceGroup \
    --query id \
    --output tsv)

az role assignment create --assignee $userPrincipal \
    --role "Storage Blob Data Owner" \
    --scope $resourceID

echo "Record this name, you will need it later in the exercise: $accountName"