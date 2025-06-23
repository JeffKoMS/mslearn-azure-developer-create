# !/bin/bash
# This script deploys resources for the exercise, used for testing
# Make sure you are logged in to the account you want to use.
# Be sure to update the resource group and location as needed

resourceGroup=rg-exercises
location=eastus
storAcctName=storactname$RANDOM

az storage account create \
    --resource-group $resourceGroup \
    --name $storAcctName \
    --location $location \
    --sku Standard_LRS

userPrincipal=$(az rest --method GET --url https://graph.microsoft.com/v1.0/me \
    --headers 'Content-Type=application/json' \
    --query userPrincipalName --output tsv)

resourceID=$(az storage account show --resource-group $resourceGroup \
    --name $storAcctName --query id --output tsv)

az role assignment create --assignee $userPrincipal \
    --role "Storage Queue Data Contributor" \
    --scope $resourceID

echo "Record this name, you will need it later in the exercise: $storAcctName"