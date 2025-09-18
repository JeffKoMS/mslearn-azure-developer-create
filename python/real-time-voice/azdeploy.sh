#!/bin/bash
rg="rg-rtvexercise"
location="eastus2"
acr_name="acrrealtime108"
image="rt-voice"
tag="v1"
appsvc_plan="rtv-app-plan5"
webapp_name="rtv-webapp-5"

clear
echo "Starting deployment, takes about 10 minutes..."

# Create ACR and build image from Dockerfile
echo
echo "Creating Azure Container Registry resource..."
az acr create -n $acr_name -g $rg --sku Basic --admin-enabled true >/dev/null
echo "  - Resource created"
echo "  - Starting image build process in 10 seconds to reduce build failures."
sleep 10 # To give time for the ACR service to be ready for build operations

echo
echo "Building image in ACR...(takes 3-5 minutes per attempt)"
# Build image with retry logic
max_retries=3
retry_count=0

while [ $retry_count -lt $max_retries ]; do
    echo "  - Attempt $((retry_count + 1)) of $max_retries: building image..."
    
    # Run the build command
    az acr build -r $acr_name --image ${acr_name}.azurecr.io/${image}:${tag} --file Dockerfile . >/dev/null 2>&1

    # Check if the image exists in the registry
    if az acr repository show --name $acr_name --repository $image >/dev/null 2>&1; then
        echo "  - Image successfully built and verified in ACR..."
        break
    else
        echo "  - Image not found in ACR, retrying build..."
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo "  - Waiting 5 seconds before retry..."
            sleep 5
        fi
    fi
done

if [ $retry_count -eq $max_retries ]; then
    echo "ERROR: Failed to build image after $max_retries attempts"
    echo "Please check your Dockerfile and try again manually with:"
    echo "az acr build -r $acr_name --image ${acr_name}.azurecr.io/${image}:${tag} --file Dockerfile ."
    exit 1
fi

echo
echo "Begin Azure App Service deployment"

echo "  - Gathering environment variables from .env file for App Service deployment.."
# Parse the .env file exists in the repo root, and bring values into the  script environment 
if [ -f .env ]; then
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

# Add performance settings to the environment variables
perf_vars=(
    WEBSITES_ENABLE_APP_SERVICE_STORAGE="false"
    WEBSITES_CONTAINER_START_TIME_LIMIT="1800"
)

echo "  - Retrieving ACR credentials so App Service can access the container image..."
# Use the retrieved ACR credentials to allow AppSvc to pull the image.
acr_user=$(az acr credential show -n $acr_name --query username -o tsv | tr -d '\r')  
acr_pass=$(az acr credential show -n $acr_name --query passwords[0].value -o tsv | tr -d '\r')
acr_login_server=$(az acr show --name $acr_name --query "loginServer" --output tsv | tr -d '\r')
acr_image=${acr_login_server}/${image}:${tag}

echo "  - Creating App Service plan: $appsvc_plan (Linux, B1)..."
az appservice plan create --name "$appsvc_plan" \
    --resource-group $rg \
    --is-linux \
    --sku B1 >/dev/null

echo "  - Creating Web App: ${webapp_name}..."
# Create the webapp with Docker runtime for container deployment
az webapp create --resource-group $rg \
    --plan $appsvc_plan \
    --name $webapp_name \
    --runtime "PYTHON:3.10" >/dev/null

echo "  - Configuring Web App container settings to pull from ACR..."
az webapp config container set \
    --name "$webapp_name" \
    --resource-group "$rg" \
    --container-image-name "$acr_image" \
    --container-registry-url "https://$acr_login_server" \
    --container-registry-user "$acr_user" \
    --container-registry-password "$acr_pass" >/dev/null

echo "  - Configuring app settings and performance optimizations..."
az webapp config set --resource-group "$rg" \
    --name "$webapp_name" \
    --startup-file "" \
    --always-on true >/dev/null

echo "  - Applying environment variables to web app..."
az webapp config appsettings set --resource-group "$rg" \
    --name "$webapp_name" \
    --settings "${env_vars[@]}" "${perf_vars[@]}" >/dev/null

# Start / Restart to ensure container is pulled
echo "  - Restarting Web App to ensure new container image is pulled..."
az webapp restart --name "$webapp_name" --resource-group "$rg" >/dev/null
sleep 15 #Time for the service to restart and pul image


# Show final URL
echo
echo "Deployment complete."
echo "Your app should be available at: https://${webapp_name}.azurewebsites.net"
echo "It may take a few minutes for the page to load."
echo


