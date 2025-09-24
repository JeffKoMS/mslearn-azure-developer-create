# Requirements

* Deploy one of the "realtime" models in AI Foundry.
* Create `.env` file in project root and add required variables
* Deploy containerized app to Azure, or run locally
* Installation of the Azure CLI if running locally, it is included in the Cloud Shell.

## Environment Variables

Create your own `.env` file in the root of this project. 

Required:
* `AZURE_VOICE_LIVE_ENDPOINT` This is the endpoint for the model and should resemble the following example:
    * `AZURE_VOICE_LIVE_ENDPOINT`="https://your-endpoint.cognitiveservices.azure.com"
* `AZURE_VOICE_LIVE_API_KEY`="Your API Key" This is located just below the endpoint for your model.
* `VOICE_LIVE_MODEL`="gpt-realtime" or your model
* `VOICE_LIVE_VOICE`="alloy" or your preferred voice
* `VOICE_LIVE_INSTRUCTIONS`="You are a helpful AI assistant with a focus on world history. Respond naturally and conversationally. Keep your responses concise but engaging."
* `VOICE_LIVE_VERBOSE`="" Note: Suppresses excessive logging to the terminal if running locally

If required variables are missing the application returns an error state (`/status`).

## Azure resource deployment

The provided `azdeploy.sh` creates the required resources in Azure:

* Change the variables at the top of the script to match your needs
* Creates Azure Container Registry service
* Uses ACR tasks to build and deploy the Dockerfile image to ACR
* Creates the App Service Plan
* Creates the App Service Web App
* Configures the web app for container image in ACR
* Configures the web app environment variables
* The script will provide the App Service endpoint

> Note: You can run the script in PowerShell using the `bash azdeploy.sh` command, this command also let's you run the script in Bash without having to make it an executable.

## Local development

The project can be run locally. It was was created and managed using **uv**, but it is not required to run.

If you have **uv** installed:

* Run `uv venv` to create the environment
* Run `uv sync` to add packages
* Alias created for web app: `uv run web` to start the `flask_app.py` script.
* requirements.txt file created with `uv pip compile pyproject.toml -o requirements.txt`

If you don't have **uv** installed:

* Create environment: `python -m venv .venv`
* Install dependencies: `pip install -r requirements.txt`
* Activate environment: `.\.venv\Scripts\Activate.ps1`
* Run application (from project root): `python .\src\real_time_voice\flask_app.py`
