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

echo "Azure Storage account $accountName created."

# Add needed role for the user
userPrincipal=$(az rest --method GET --url https://graph.microsoft.com/v1.0/me \
    --headers 'Content-Type=application/json' \
    --query userPrincipalName --output tsv)

echo "User principal: $userPrincipal"

resourceID=$(az storage account show \
    --name $accountName \
    --resource-group $resourceGroup \
    --query id \
    --output tsv)

echo "Resource ID: $resourceID"

az role assignment create --assignee $userPrincipal \
    --role "Storage Blob Data Owner" \
    --scope $resourceID