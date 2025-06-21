az appconfig create --location $location \
    --name $appConfigName \
    --resource-group $resourceGroup \
    --disable-local-auth true

az appconfig kv set --name $appConfigName \
    --key Dev:conStr \
    --value connectionString

