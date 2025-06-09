resourceGroup=rg-exercises
location=eastus
namespaceName=svcbusns$RANDOM


az servicebus namespace create -g $resourceGroup -n $namespaceName -l $location

az servicebus queue create -g $resourceGroup --namespace-name $namespaceName --name myQueue


# NOT DefaultCredential

servicebusConnStr=$(
  az servicebus namespace authorization-rule keys list \
    --resource-group $resourceGroup \
    --namespace-name $namespaceName \
    --name RootManageSharedAccessKey \
    --query primaryConnectionString \
    --output tsv
)

echo $servicebusConnStr


# DEFAULT CREDENTIAL - NEED TO ASSIGN ROLE

userPrincipal=$(az rest --method GET --url https://graph.microsoft.com/v1.0/me --headers 'Content-Type=application/json' --query userPrincipalName --output tsv)

resourceID=$(az servicebus namespace show --name $namespaceName --resource-group $resourceGroup --query id --output tsv)

az role assignment create --assignee $userPrincipal --role "Azure Service Bus Data Owner" --scope $resourceID