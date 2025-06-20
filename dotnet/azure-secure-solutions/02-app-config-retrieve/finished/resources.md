az appconfig create --location $location \
    --name $appconfigName \
    --resource-group $resourceGroup \
    --disable-local-auth true

az appconfig kv set --name $appconfigName \
    --key Dev:conStr \
    --value connectionString

