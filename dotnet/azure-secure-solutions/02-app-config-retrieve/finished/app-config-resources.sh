# !/bin/bash
# This script deploys resources for the exercise, used for testing
# Make sure you are logged in to the account you want to use.
# Be sure to update the resource group and location as needed

resourceGroup=rg-exercises
location=eastus
appConfigName=appconfigname$RANDOM

az appconfig create --location $location \
    --name $appConfigName \
    --resource-group $resourceGroup \
    --disable-local-auth true

userPrincipal=$(az rest --method GET --url https://graph.microsoft.com/v1.0/me \
    --headers 'Content-Type=application/json' \
    --query userPrincipalName --output tsv)

resourceID=$(az appconfig show --resource-group $resourceGroup \
    --name $appConfigName --query id --output tsv)

az role assignment create --assignee $userPrincipal \
    --role "App Configuration Data Reader" \
    --scope $resourceID

echo "Record this name, you will need it later in the exercise: $appConfigName"
