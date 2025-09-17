#!/bin/bash
rg=rg-rtvexercise
location=eastus2
acr_name=acrrealtime105 #acrrealtime$RANDOM
image="rt-voice"
tag="v1"

# Create ACR and build image from Dockerfile
echo "Crate Azure Container registry and building image."
az acr create -n $acr_name -g $rg --sku Basic --admin-enabled true >/dev/null
az acr build -r $acr_name --image ${acr_name}.azurecr.io/${image}:${tag} --file Dockerfile . >/dev/null

# List image in ACR to verify deployment
echo "Verify image successfully deployed to ACR, it can fail occasionally."
az acr repository list --name $acr_name --output table
echo "If you see your image in the table, press any key to continue."
echo "Press ctrl+c if your image isn't listed"
read -n 1 -s -r -p 
clear

echo "Retrieving name/password from ACR to allow App Service to access the container image"
acr_user=$(az acr credential show -n $acr_name --query username -o tsv | tr -d '\r')  
acr_pass=$(az acr credential show -n $acr_name --query passwords[0].value -o tsv | tr -d '\r')
acr_login_server=$(az acr show --name $acr_name --query "loginServer" --output tsv | tr -d '\r')
acr_image=${acr_login_server}/${image}:${tag}


echo "Gathering environment variables for deployment"


# Use the retrieved ACR credentials to allow AppSvc to pull the image.
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

# Build env_vars using values from .env - one file to update
env_vars=(
    AZURE_VOICE_LIVE_ENDPOINT="${AZURE_VOICE_LIVE_ENDPOINT}"
    AZURE_VOICE_LIVE_API_KEY="${AZURE_VOICE_LIVE_API_KEY}"
    VOICE_LIVE_MODEL="${VOICE_LIVE_MODEL}"
    VOICE_LIVE_VOICE="${VOICE_LIVE_VOICE}"
    VOICE_LIVE_INSTRUCTIONS="${VOICE_LIVE_INSTRUCTIONS}"
)

echo "Begin deployment to Azure App Service..."

appsvc_plan=rtv-app-plan
webapp_name=rtv-app-web-2

echo "Creating App Service plan: $appsvc_plan (Linux, B1)"
az appservice plan create --name "$appsvc_plan" \
    --resource-group $rg \
    --is-linux \
    --sku B1 >/dev/null

echo "Creating Web App: $webapp_name"
# Create the webapp with Docker runtime for container deployment
az webapp create --resource-group $rg \
    --plan $appsvc_plan \
    --name $webapp_name \
    --runtime "PYTHON:3.10" >/dev/null

echo "Configuring Web App container settings to pull from ACR (using retrieved credentials)"
az webapp config container set \
    --name "$webapp_name" \
    --resource-group "$rg" \
    --container-image-name "$acr_image" \
    --container-registry-url "https://$acr_login_server" \
    --container-registry-user "$acr_user" \
    --container-registry-password "$acr_pass" >/dev/null


echo "Applying environment variables to web app."
if [ ${#env_vars[@]} -gt 0 ]; then
    echo "Setting App Settings (environment variables) on Web App..."
    az webapp config appsettings set --resource-group "$rg" \
        --name "$webapp_name" \
        --settings "${env_vars[@]}" >/dev/null
fi

# Start / Restart to ensure container is pulled
echo "Restarting Web App to ensure new container image is pulled..."
az webapp restart --name "$webapp_name" --resource-group "$rg" >/dev/null

# Show final URL
echo
echo "App Service deployment complete."
echo "Your app should be available at: https://${webapp_name}.azurewebsites.net"
echo "It may take a few minutes to start."
echo


