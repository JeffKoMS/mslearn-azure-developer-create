# !/bin/bash
# This script deploys resources for the event grid exercise, used for testing
# Be sure to update the resource group and location as needed

let rNum=$RANDOM
resourceGroup=rg-exercises
location=eastus
topicName="mytopic-evgtopic-${rNum}"
siteName="evgsite-${rNum}"
siteURL="https://${siteName}.azurewebsites.net"

# register needed namespace
az provider register --namespace Microsoft.EventGrid

# create an event grid topic
az eventgrid topic create --name $topicName \
    --location $location \
    --resource-group $resourceGroup

# Create a messaging endpoint for the event grid topic
az deployment group create \
    --resource-group $resourceGroup \
    --template-uri "https://raw.githubusercontent.com/Azure-Samples/azure-event-grid-viewer/main/azuredeploy.json" \
    --parameters siteName=$siteName hostingPlanName=viewerhost

echo "Your web app URL: ${siteURL}"


# Create an event subscription for the topic
endpoint="${siteURL}/api/updates"
topicId=$(az eventgrid topic show --resource-group $resourceGroup \
    --name $topicName --query "id" --output tsv)

az eventgrid event-subscription create \
    --source-resource-id $topicId \
    --name TopicSubscription \
    --endpoint $endpoint

# retrieve the topic endpoint and key
az eventgrid topic show --name $topicName -g $resourceGroup --query "endpoint" --output tsv
az eventgrid topic key list --name $topicName -g $resourceGroup --query "key1" --output tsv
