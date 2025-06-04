rgName="contosorg$RANDOM"
region="eastus"
az group create --name $rgName --location $region



# Create an Event Hubs namespace
namespaceName="contosoehubns$RANDOM"
az eventhubs namespace create --name $namespaceName --resource-group $rgName -l $region

# Create an event hub. Specify a name for the event hub. 
eventhubName="contosoehub$RANDOM"
az eventhubs eventhub create --name $eventhubName --resource-group $rgName --namespace-name $namespaceName

# Get the resource ID for the namespace
az eventhubs namespace show -g '<your-event-hub-resource-group>' -n '<your-event-hub-name> --query id

## Assign the role

az role assignment create --assignee "<user@domain>" --role "Azure Event Hubs Data Owner" --scope "<your-resource-id>"