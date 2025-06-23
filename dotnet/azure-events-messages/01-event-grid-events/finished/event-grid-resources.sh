# !/bin/bash
# This script deploys resources for the exercise, used for testing
# Make sure you are logged in to the account you want to use.
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

echo "Your web app URL: ${siteURL}", open the link before continuing
read -p "Press enter to continue once the web app is open..."

# Create an event subscription for the topic
endpoint="${siteURL}/api/updates"
topicId=$(az eventgrid topic show --resource-group $resourceGroup \
    --name $topicName --query "id" --output tsv)

az eventgrid event-subscription create \
    --source-resource-id $topicId \
    --name TopicSubscription \
    --endpoint $endpoint

# retrieve the topic endpoint and key
echo "Record the topic endpoint and key below, you will need them later"
az eventgrid topic show --name $topicName -g $resourceGroup --query "endpoint" --output tsv
az eventgrid topic key list --name $topicName -g $resourceGroup --query "key1" --output tsv
