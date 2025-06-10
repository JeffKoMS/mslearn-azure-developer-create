storAcctName=storactname$RANDOM
resourceGroup=rg-exercises
location=eastus

echo $storAcctName

az storage account create --resource-group $resourceGroup \
    --name $storAcctName --location $location --sku Standard_LRS

userPrincipal=$(az rest --method GET --url https://graph.microsoft.com/v1.0/me \
    --headers 'Content-Type=application/json' \
    --query userPrincipalName --output tsv)

resourceID=$(az storage account show --resource-group $resourceGroup \
    --name $storAcctName --query id --output tsv)

az role assignment create --assignee $userPrincipal \
    --role "Storage Queue Data Contributor" \
    --scope $resourceID