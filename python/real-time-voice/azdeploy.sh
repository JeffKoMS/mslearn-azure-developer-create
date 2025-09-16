#!/bin/bash
rg=rg-exercises
location=eastus2
acr_name=acrrealtime6919 #acrrealtime$RANDOM
image="rt-voice"
tag="v1"
dns_label=realtime-voice-159783 #realtime-voice-$RANDOM
openai_resource_name="rtv-exercise-resource"
aci_name="aci-realtime"

# Create ACR and build image from Dockerfile
az acr create -n $acr_name -g $rg --sku Basic --admin-enabled true
az acr build -r $acr_name --image ${acr_name}.azurecr.io/${image}:${tag} --file Dockerfile .

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

# Create the ACI instance with the container
az container create -g $rg -n aci-realtimevoice \
    --image $acr_image \
    --registry-login-server $acr_login_server \
    --registry-username $acr_user \
    --registry-password "$acr_pass" \
    --assign-identity \
    --ports 5000 \
    --environment-variables "${env_vars[@]}" \
    --location $location \
    --dns-name-label $dns_label \
    --os-type Linux \
    --cpu 1 \
    --memory 1.5

echo "ACI created, assigning roles"
read -n 1 -s -r -p "Press any key to continue..."

aci_principal_id=$(az container show -g $rg -n $aci_name --query identity.principalId -o tsv)

az role assignment create \
  --assignee $aci_principal_id \
  --role "Cognitive Services OpenAI User" \
  --scope $(az cognitiveservices account show -g $rg -n $openai_resource_name --query id -o tsv)

echo "deployment complete"