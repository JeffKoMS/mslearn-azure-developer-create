# !/bin/bash
# This script deploys resources for the event grid exercise, used for testing
# Be sure to update the resource group and location as needed

resourceGroup=rg-exercises
location=eastus
namespaceName=svcbusns$RANDOM

# Create a service bus namespace
az servicebus namespace create \
    --resource-group $resourceGroup \
    --name $namespaceName \
    --location $location

# Create a service bus queue
az servicebus queue create \
    --resource-group $resourceGroup \
    --namespace-name $namespaceName \
    --name myqueue

# Get the user principal name for the current user
userPrincipal=$(az rest --method GET --url https://graph.microsoft.com/v1.0/me \
    --headers 'Content-Type=application/json' \
    --query userPrincipalName --output tsv)

# Get the resource ID for the namespace
resourceID=$(az servicebus namespace show --name $namespaceName \
    --resource-group $resourceGroup \
    --query id --output tsv)

# Assign the "Azure Service Bus Data Owner" role to the user for the namespace
az role assignment create --assignee $userPrincipal \
    --role "Azure Service Bus Data Owner" \
    --scope $resourceID

echo "Record this name, you will need it later in the exercise: $namespaceName"
