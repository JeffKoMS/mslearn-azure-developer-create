#!/bin/bash
rg=rg-exercises
location=eastus2
acr_name=acrrealtime9999 #acrrealtime$RANDOM
image="rt-voice"
tag="v1"
dns_label=realtime-test-159785 #realtime-voice-$RANDOM
openai_resource_name="rtv-exercise-resource"
aci_name="aci-realtime"
uami_name="aci-uami"

# Create ACR and build image from Dockerfile
#az acr create -n $acr_name -g $rg --sku Basic --admin-enabled true
#az acr build -r $acr_name --image ${acr_name}.azurecr.io/${image}:${tag} --file Dockerfile .

# List image in ACR to verify deployment
clear
az acr repository list --name $acr_name --output table

echo "Verify image successfully deployed to ACR..."
read -n 1 -s -r -p "Press any key to continue..."
clear

echo "Creating ACI and pulling image from ACR."

# Set environment variables to pass to container
env_vars=(
    AZURE_VOICE_LIVE_ENDPOINT="https://${openai_resource_name}.cognitiveservices.azure.com/"
    VOICE_LIVE_MODEL="gpt-realtime"
    VOICE_LIVE_VOICE="alloy"
    VOICE_LIVE_INSTRUCTIONS="You are a helpful AI assistant. Respond naturally and conversationally. Keep your responses concise but engaging."
)


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

## uami_client_id=$(az identity show -g $rg -n $uami_name --query clientId -o tsv | tr -d '\r')
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
else
    echo "Proceeding to create the ACI. Press any key to continue..."
    read -n 1 -s -r
fi

# Create the ACI instance with the container using the UAMI
az container create -g $rg -n $aci_name \
    --image $acr_image \
    --registry-login-server $acr_login_server \
    --registry-username $acr_user \
    --registry-password "$acr_pass" \
    --assign-identity "$uami_resource_id" \
    --ports 5000 \
    --environment-variables "${env_vars[@]}"  \
    --location $location \
    --dns-name-label $dns_label \
    --os-type Linux \
    --cpu 1 \
    --memory 1.5

echo "deployment complete"