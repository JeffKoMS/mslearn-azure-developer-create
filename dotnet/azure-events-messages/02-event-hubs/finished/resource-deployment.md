rgName="myResourceGroup"
region="eastus"
az group create --name $rgName --location $region

# Create an Event Hubs namespace
namespaceName=eventhubsns$RANDOM
az eventhubs namespace create --name $namespaceName --resource-group $rgName -l $region

# Create an event hub. Specify a name for the event hub. 
eventhubName=myEventHub$RANDOM
az eventhubs eventhub create --name $eventhubName --resource-group $rgName --namespace-name $namespaceName
echo $eventhubName

# Get conn string to Hub namespace (requires event hub inclusion)

eventhubConnStr=$(az eventhubs eventhub authorization-rule keys list -g $rgName --namespace-name $namespaceName --eventhub-name $eventhubName --name MyAuthRuleName)

echo $eventhubConnStr

