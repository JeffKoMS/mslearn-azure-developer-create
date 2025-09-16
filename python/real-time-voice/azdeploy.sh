#!/bin/bash
rg=rg-exercises
location=eastus2
acr_name=acrrealtime1000000 #acrrealtime$RANDOM
image="rt-voice"
tag="v1"
dns_label=realtime-test-159788 #realtime-voice-$RANDOM
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


echo "Creating user-assigned identity..."

# Retrieve name/password from ACR to allow ACI to access the container image
acr_user=$(az acr credential show -n $acr_name --query username -o tsv | tr -d '\r')  
acr_pass=$(az acr credential show -n $acr_name --query passwords[0].value -o tsv | tr -d '\r')
acr_login_server=$(az acr show --name $acr_name --query "loginServer" --output tsv | tr -d '\r')
acr_image=${acr_login_server}/${image}:${tag}

# Ensure a user-assigned managed identity exists (minimal change)
if ! az identity show -g $rg -n $uami_name --query id -o tsv &>/dev/null; then
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
        echo "Role assignment confirmed (found $count)."
        assigned=1
        break
    fi
    echo "Waiting for role assignment to propagate... ($i/10)"
    sleep 6
done

if [[ $assigned -ne 1 ]]; then
    echo "Role assignment not visible after wait. Press any key to continue (you can inspect and assign manually), or Ctrl-C to abort."
    read -n 1 -s -r
fi

echo "Proceeding to deploy to Azure Container Apps (ACA). Press any key to continue..."
read -n 1 -s -r

# Create Log Analytics workspace (required by Container Apps)
la_workspace="${acr_name}-log"
az monitor log-analytics workspace create -g $rg -n $la_workspace --location $location

# Create Container Apps environment
aca_env="aca-env-${RANDOM}"
az containerapp env create -g $rg -n $aca_env --location $location --log-analytics-workspace $la_workspace

# Register ACR with the Container Apps environment (grant pull permissions via role assignment)
acr_server=$acr_login_server
echo "Granting acr pull role for Container Apps to ACR..."
az role assignment create --assignee-principal-type ServicePrincipal --assignee $(az ad sp show --id "http://${acr_name}" --query objectId -o tsv 2>/dev/null || echo "") --role AcrPull --scope $(az acr show -n $acr_name -g $rg --query id -o tsv)

# Deploy the Container App with system-assigned managed identity and ACR integration
containerapp_name="rt-voice-app"
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
  --cpu 1 \
  --memory 1.5Gi \
  --environment-variables "${env_vars[@]}" \
  --location $location \
  --assign-identity system

echo "Container App deployed. Retrieving principal id for the app's managed identity..."
app_principal_id=$(az containerapp show -g $rg -n $containerapp_name --query identity.principalId -o tsv)
echo "App principalId: $app_principal_id"

echo "Assigning 'Cognitive Services OpenAI User' role to the Container App managed identity on the OpenAI resource..."
az role assignment create --assignee-object-id "$app_principal_id" --assignee-principal-type ServicePrincipal --role "Cognitive Services OpenAI User" --scope "$openai_scope" || true

echo "Deployment complete. Use 'az containerapp show' and 'az containerapp logs' to inspect the app and logs."