#!/bin/bash
# This script is used to set up the Azure resources for the project.
# Be sure  to update the resource group name and location as needed.

resourceGroup=rg-exercises
location=eastus
namespaceName=eventhubsns$RANDOM

echo "Record this name: ${namespaceName}, it will be used later in the lab."
read -p "Press enter to continue..."

# Create an event hub namespace
az eventhubs namespace create --name $namespaceName --resource-group $resourceGroup -l $location

# Create an event hub
az eventhubs eventhub create --name myEventHub --resource-group $resourceGroup \
    --namespace-name $namespaceName

# Assign the "Azure Event Hubs Data Owner" role to the user, allows send and receive operations

userPrincipal=$(az rest --method GET --url https://graph.microsoft.com/v1.0/me \
    --headers 'Content-Type=application/json' \
    --query userPrincipalName --output tsv)

resourceID=$(az eventhubs namespace show --resource-group $resourceGroup \
    --name $namespaceName --query id --output tsv)

az role assignment create --assignee $userPrincipal \
    --role "Azure Event Hubs Data Owner" \
    --scope $resourceID