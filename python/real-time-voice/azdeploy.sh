#!/bin/bash
rg=rg-exercises
location=eastus2
acr_name=acrrealtime23830 #acrrealtime$RANDOM
image="rt-voice"
tag="v1"
dns_label=realtime-voice-$RANDOM

# az acr create -n $acr_name -g $rg --sku Basic --admin-enabled true
# az acr build -r $acr_name --image $acr_name.azurecr.io/${image}:${tag} --file Dockerfile .
# az acr repository list --name $acr_name --output table

# echo "Image deployed to ACR..."
# read -n 1 -s -r -p "Press any key to continue..."

# Get admin credentials
acr_user=$(az acr credential show -n $acr_name --query username -o tsv)
acr_pass=$(az acr credential show -n $acr_name --query passwords[0].value -o tsv)


# sanity check
echo "\nUser: $acr_user"
echo "Pass: $acr_pass"

echo "Identities and access set."
#read -n 1 -s -r -p "Press any key to continue..."

# Set environment variables to pass to container
env_vars=(
    AZURE_VOICE_LIVE_ENDPOINT="https://jeffko-voice-live-resource.cognitiveservices.azure.com/"
    VOICE_LIVE_MODEL="gpt-4o-realtime-preview"
    VOICE_LIVE_VOICE="alloy"
    VOICE_LIVE_INSTRUCTIONS="You are a helpful AI assistant. Respond naturally and conversationally. Keep your responses concise but engaging."
)

az container create -g $rg -n aci-realtimevoice \
    --image acrrealtime23830.azurecr.io/${image}:${tag} \
    --registry-login-server acrrealtime23830.azurecr.io \
    --registry-username acrrealtime23830 \
    --registry-password 2TU3YKlM1Bai9SNJpI6Hmt4IqPTaoZX0xCK+xT4TMj+ACRCFllk4 \
    --ports 5000 \
    --environment-variables "${env_vars[@]}" \
    --location $location \
    --dns-name-label $dns_label \
    --os-type Linux \
    --cpu 1 \
    --memory 1.5

    #--environment-variables "${env_vars[@]}" \