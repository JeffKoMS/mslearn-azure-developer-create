#!/bin/bash
rg=rg-rtvexercise
location=eastus2
acr_name=acrrealtime1000004 #acrrealtime$RANDOM
image="rt-voice"
tag="v1"
dns_label=realtime-test-159791 #realtime-voice-$RANDOM
aci_name="aci-realtime-app"

# Create ACR and build image from Dockerfile
#az acr create -n $acr_name -g $rg --sku Basic --admin-enabled true
#az acr build -r $acr_name --image ${acr_name}.azurecr.io/${image}:${tag} --file Dockerfile .
#
## List image in ACR to verify deployment
#clear
#az acr repository list --name $acr_name --output table
#
#echo "Verify image successfully deployed to ACR..."
#read -n 1 -s -r -p "Press any key to continue..."
#clear



# Retrieve name/password from ACR to allow ACI to access the container image
acr_user=$(az acr credential show -n $acr_name --query username -o tsv | tr -d '\r')  
acr_pass=$(az acr credential show -n $acr_name --query passwords[0].value -o tsv | tr -d '\r')
acr_login_server=$(az acr show --name $acr_name --query "loginServer" --output tsv | tr -d '\r')
acr_image=${acr_login_server}/${image}:${tag}


echo "Proceeding to deploy to Azure Container Instances (ACI). Press any key to continue..."
read -n 1 -s -r

echo "Creating Azure Container Instance"

# Use the retrieved ACR credentials to allow ACI to pull the image.
# Parse the .env file exists in the repo root, and bring values into the  script environment 
if [ -f .env ]; then
    echo "Loading environment variables from .env"
    while IFS='=' read -r key val; do
        # Trim whitespace
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Skip comments and empty lines
        case "$key" in
            ""|\#*) continue;;
        esac
        # Join remainder of line in case value contains '='
        if echo "$val" | grep -q "="; then
            # Re-read the whole line and extract first = split only
            val=$(echo "${key}=${val}" | sed 's/^[^=]*=//')
        fi
        val=$(echo "$val" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Remove surrounding quotes if present
        val="${val%\"}"
        val="${val#\"}"
        val="${val%\'}"
        val="${val#\'}"
        # Export into shell variable
        eval "${key}='${val}'"
    done < .env
fi

# Build env_vars using values from .env if present, otherwise fall back to defaults
env_vars=(
    AZURE_VOICE_LIVE_ENDPOINT="${AZURE_VOICE_LIVE_ENDPOINT}"
    AZURE_VOICE_LIVE_API_KEY="${AZURE_VOICE_LIVE_API_KEY}"
    VOICE_LIVE_MODEL="${VOICE_LIVE_MODEL}"
    VOICE_LIVE_VOICE="${VOICE_LIVE_VOICE}"
    VOICE_LIVE_INSTRUCTIONS="${VOICE_LIVE_INSTRUCTIONS}"
)

    # Echo the env vars that will be supplied to the container for visibility
    echo "Environment variables to be passed to ACI:"
    for kv in "${env_vars[@]}"; do
        echo "  $kv"
    done
read -n 1 -s -r -p "Press any key to continue..."

az container create \
    --resource-group $rg \
    --name $aci_name \
    --image $acr_image \
    --registry-login-server $acr_login_server \
    --registry-username "$acr_user" \
    --registry-password "$acr_pass" \
    --os-type Linux \
    --cpu 1 \
    --memory 2 \
    --ports 5000 \
    --ip-address public \
    --dns-name-label $dns_label \
    --environment-variables "${env_vars[@]}" \
    --restart-policy Always

echo "ACI deployed. You can inspect the container with 'az container show' and view logs with 'az container logs'."