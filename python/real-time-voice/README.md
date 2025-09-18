# Deployment

The provided `azdeploy.sh` creates the required resources in Azure:

* Change the variables at the top of the script to match your needs
* Creates Azure Container Registry service
* Uses ACR to build and deploy the Dockerfile image to ACR
* Creates the App Service Plan
* Creates the App Service Web App
* Configures the web app for container image in ACR
* Configures the web app environment variables

## Environment Variables

Need to create your own .env file in the root directory. 

Required:
* `AZURE_VOICE_LIVE_ENDPOINT`="https://<endpoint for model>.cognitiveservices.azure.com"
* `AZURE_VOICE_LIVE_API_KEY`="Your API Key"
* `VOICE_LIVE_MODEL`="gpt-realtime" or your model
* `VOICE_LIVE_VOICE`="alloy" or your preferred voice
* `VOICE_LIVE_INSTRUCTIONS`="You are a helpful AI assistant with a focus on world history. Respond naturally and conversationally. Keep your responses concise but engaging."
* `VOICE_LIVE_VERBOSE`="" #Suppresses excessive logging to the terminal if running locally

If required variables are missing the application returns an error state (`/status`).

## Local development

* Managed with UV
* Alias created for web app: `uv run web` to start the `flask_app.py` script.
* requirements.txt file created with `uv pip compile pyproject.toml -o requirements.txt`