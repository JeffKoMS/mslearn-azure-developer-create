#!/bin/bash
# This script is used to set up the Azure resources for the project.
# Be sure  to update the resource group name, location isn't needed for this exercise.

resourceGroup=rg-exercises
location=eastus
accountName=cosmosexercise$RANDOM

# Create a Cosmos account
echo "Creating Cosmos DB account, can take a few minutes..."
az cosmosdb create --name $accountName \
    --resource-group $resourceGroup

# Info you need to complete the lab
echo "Record the following information for the lab:"
az cosmosdb show --name $accountName \
    --resource-group $resourceGroup \
    --query "documentEndpoint" --output tsv

az cosmosdb keys list --name $accountName \
    --resource-group $resourceGroup \
    --query "primaryMasterKey" --output tsv