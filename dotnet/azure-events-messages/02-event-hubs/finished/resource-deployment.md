resourceGroup="myResourceGroup"
location="eastus"
az group create --name $rgName --location $region

# Create an Event Hubs namespace
namespaceName=eventhubsns$RANDOM
az eventhubs namespace create --name $namespaceName --resource-group $resourceGroup -l $location

# Create an event hub. Specify a name for the event hub. 
az eventhubs eventhub create --name myEventHub --resource-group $resourceGroup --namespace-name $namespaceName


# Get conn string to Hub namespace (requires event hub inclusion)

eventhubConnStr=$(az eventhubs eventhub authorization-rule keys list -g $resourceGroup --namespace-name $namespaceName --eventhub-name myEventHub --name MyAuthRuleName);EntityPath=myEventHub

echo $eventhubConnStr

