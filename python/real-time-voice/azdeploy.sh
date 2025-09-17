#!/bin/bash
rg=rg-rtvexercise
location=eastus2
acr_name=acrrealtime1000003 #acrrealtime$RANDOM
image="rt-voice"
tag="v1"
dns_label=realtime-test-159790 #realtime-voice-$RANDOM
openai_resource_name="rtv-exercise-resource"
aci_name="aci-realtime"
uami_name="aci-uami"

# Create ACR and build image from Dockerfile
az acr create -n $acr_name -g $rg --sku Basic --admin-enabled true
az acr build -r $acr_name --image ${acr_name}.azurecr.io/${image}:${tag} --file Dockerfile .

# List image in ACR to verify deployment
clear
az acr repository list --name $acr_name --output table

echo "Verify image successfully deployed to ACR..."
read -n 1 -s -r -p "Press any key to continue..."
clear
#
#
echo "Creating user-assigned identity..."

# Retrieve name/password from ACR to allow ACI to access the container image
acr_user=$(az acr credential show -n $acr_name --query username -o tsv | tr -d '\r')  
acr_pass=$(az acr credential show -n $acr_name --query passwords[0].value -o tsv | tr -d '\r')
acr_login_server=$(az acr show --name $acr_name --query "loginServer" --output tsv | tr -d '\r')
acr_image=${acr_login_server}/${image}:${tag}

# Ensure a user-assigned managed identity exists (minimal change)
if ! az identity show -g $rg -n $uami_name --query id -o tsv &>/dev/null; then
    echo ""
    echo "Creating user-assigned managed identity: ${uami_name}"
    az identity create -g $rg -n $uami_name --location $location
fi

uami_client_id=$(az identity show -g $rg -n $uami_name --query clientId -o tsv | tr -d '\r')
uami_resource_id=$(az identity show -g $rg -n $uami_name --query id -o tsv | tr -d '\r')
uami_principal_id=$(az identity show -g $rg -n $uami_name --query principalId -o tsv | tr -d '\r')

# Assign Cognitive Services role to the UAMI
openai_scope=$(az cognitiveservices account show -g $rg -n $openai_resource_name --query id -o tsv | tr -d '\r')
echo "Assigning 'Cognitive Services OpenAI User' to UAMI ($uami_name) on scope: $openai_scope"
az role assignment create \
    --assignee-object-id "$uami_principal_id" \
    --assignee-principal-type ServicePrincipal \
    --role "Cognitive Services OpenAI User" \
    --scope "$openai_scope" || true

# Verify the role assignment exists (wait up to ~60s)
echo "Verifying role assignment for UAMI principal id: $uami_principal_id"
assigned=0
for i in {1..10}; do
    count=$(az role assignment list --assignee-object-id "$uami_principal_id" --scope "$openai_scope" --query "length([?roleDefinitionName=='Cognitive Services OpenAI User'])" -o tsv 2>/dev/null || echo 0)
    if [[ "$count" != "0" && -n "$count" ]]; then
        echo ""
        echo "Role assignment confirmed (found $count)."
        assigned=1
        break
    fi
    echo "Waiting for role assignment to propagate... ($i/10)"
    sleep 6
done

if [[ $assigned -ne 1 ]]; then
    echo "Role assignment not visible after wait. Press any key to continue (you can inspect and assign #manually), or Ctrl-C to abort."
    read -n 1 -s -r
fi

echo "Proceeding to deploy to Azure Container Apps (ACA). Press any key to continue..."
read -n 1 -s -r


# Create Log Analytics workspace (required by Container Apps)
echo "Creating Log Analytics workspace"
la_workspace="${acr_name}-log"
az monitor log-analytics workspace create -g $rg -n $la_workspace --location $location

# Create Container Apps environment
echo "Create Container Apps environment"
aca_env=aca-env-2732 #"aca-env-${RANDOM}"
la_workspace_customer_id=$(az monitor log-analytics workspace show -g $rg -n $la_workspace --query customerId -o tsv | tr -d '\r')
# Also fetch the workspace shared key and provide it to the env create command
la_workspace_key=$(az monitor log-analytics workspace get-shared-keys -g $rg -n $la_workspace --query primarySharedKey -o tsv | tr -d '\r')
az containerapp env create -g $rg -n $aca_env \
    --logs-workspace-id "$la_workspace_customer_id" \
    --logs-workspace-key "$la_workspace_key" \
    --location $location



# Deploy the Container App with system-assigned managed identity and ACR integration
containerapp_name="rt-voice-app2"
env_vars=(
    AZURE_VOICE_LIVE_ENDPOINT="https://${openai_resource_name}.cognitiveservices.azure.com/"
    VOICE_LIVE_MODEL="gpt-realtime"
    VOICE_LIVE_VOICE="alloy"
    VOICE_LIVE_INSTRUCTIONS="You are a helpful AI assistant. Respond naturally and conversationally. Keep your responses concise but engaging."
)

az containerapp create \
    --name $containerapp_name \
    --resource-group $rg \
    --environment $aca_env \
    --image $acr_image \
    --ingress external \
    --target-port 5000 \
    --registry-server $acr_login_server \
    --registry-username "$acr_user" \
    --registry-password "$acr_pass" \
    --cpu 1 \
    --memory 2.0Gi \
    --env-vars "${env_vars[@]}" \
    --user-assigned $uami_resource_id

echo "Container App deployed. Retrieving principal id for the app's managed identity..."
#app_principal_id=$(az containerapp show -g $rg -n $containerapp_name --query identity.principalId -o tsv | tr -d '\r')
#echo "Container App principalId: $app_principal_id"

# Note: we assigned the 'Cognitive Services OpenAI User' role earlier to the user-assigned managed identity (UAMI).
# The Container App is created with that UAMI attached (see --user-assigned), so it will use the UAMI principalId ($uami_principal_id).
# If you prefer to assign roles directly to the app principal, uncomment the following line.
# az role assignment create --assignee-object-id "$app_principal_id" --assignee-principal-type ServicePrincipal --role "Cognitive Services OpenAI User" --scope "$openai_scope" || true

echo "Deployment complete. Use 'az containerapp show' and 'az containerapp logs' to inspect the app and logs."