# !/bin/bash
# This script deploys resources for the event grid exercise, used for testing
# Be sure to update the resource group and location as needed

resourceGroup=rg-exercises
location=eastus
keyVaultName=mykeyvaultname$RANDOM

az keyvault create --name $keyVaultName \
    --resource-group $resourceGroup \
    --location $location

userPrincipal=$(az rest --method GET --url https://graph.microsoft.com/v1.0/me \
    --headers 'Content-Type=application/json' \
    --query userPrincipalName --output tsv)

resourceID=$(az keyvault show --resource-group $resourceGroup \
    --name $keyVaultName --query id --output tsv)

az role assignment create --assignee $userPrincipal \
    --role "Key Vault Secrets Officer" \
    --scope $resourceID

echo "Record this name, you will need it later in the exercise: $keyVaultName"
