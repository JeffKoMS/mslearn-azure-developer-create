## Real-Time Voice

Minimal project scaffold with a simple Flask single-page application.

### Installation (using uv)

```bash
uv sync
```

Or using pip in editable mode:

```bash
pip install -e .
```

### Run the CLI demo

Preferred short script name (after install / sync):

```bash
uv run console
```

Or directly as an installed script if the environment's bin is on PATH:

```bash
console
```

Legacy (still present if you kept commented lines removed): `real-time-voice`.

### Run the Flask dev server

Short name via uv:

```bash
uv run web
```

Or installed script directly:

```bash
web
```

Legacy (if retained): `real-time-voice-web`.

Or via the module path:

```bash
python -m real_time_voice.flask_app
```

Then open http://127.0.0.1:5000/ in your browser.

### Development Notes

* CLI entry: `src/real_time_voice/voice_console.py` (renamed from `cli.py`; hyphens aren't valid in module names so we use an underscore).
* Flask app: `src/real_time_voice/flask_app.py`.
* Templates: `src/real_time_voice/templates/`.
* Package now includes an `__init__.py` so build tooling (hatchling) can auto-detect the package; it exposes `__version__`.
* For production deployments consider using a production WSGI/ASGI server (e.g. gunicorn + gevent or uvicorn with an ASGI framework) and disabling `debug=True`.

### Authentication & Authorization

The application now uses `DefaultAzureCredential` (from `azure-identity`) – no API keys. When deployed to Azure Container Instances (ACI) it will use the container's Managed Identity. Locally it will fall back to (in order): Environment variables / Workload Identity, Managed Identity (if available), Azure CLI sign-in, Visual Studio Code, etc. InteractiveBrowser is explicitly disabled inside the container to avoid unexpected prompts.

Grant the Managed Identity (system-assigned or user-assigned) appropriate data-plane access to your Azure OpenAI (or Voice Live) resource. Typically you need: 

* Cognitive Services OpenAI User (built-in role) – allows calling inference endpoints.
* If logging to other Azure resources (e.g., Blob, App Insights) grant those respective Data Reader/Contributor roles as needed.

If you use a User Assigned Managed Identity (UAMI), set `AZURE_CLIENT_ID` in the container environment to force `DefaultAzureCredential` to select it.

#### Required Role Assignments

Assign at the scope of the specific Cognitive Services / Azure OpenAI resource (least privilege) or the resource group.

```bash
# Variables
RESOURCE_GROUP="<rg-name>"
OPENAI_RESOURCE_NAME="<azure-openai-resource>"   # The Cognitive Services / Azure OpenAI account
IDENTITY_NAME="<uami-name-if-used>"              # Skip if using system-assigned identity

# (Optional) get principal ID for user-assigned identity
PRINCIPAL_ID=$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_NAME --query principalId -o tsv)

# Role assignment (Cognitive Services OpenAI User)
az role assignment create \
	--assignee $PRINCIPAL_ID \
	--role "Cognitive Services OpenAI User" \
	--scope $(az cognitiveservices account show -g $RESOURCE_GROUP -n $OPENAI_RESOURCE_NAME --query id -o tsv)

# For system-assigned identity on the ACI instance:
ACI_NAME="<aci-name>"
ACI_PRINCIPAL_ID=$(az container show -g $RESOURCE_GROUP -n $ACI_NAME --query identity.principalId -o tsv)
az role assignment create \
	--assignee $ACI_PRINCIPAL_ID \
	--role "Cognitive Services OpenAI User" \
	--scope $(az cognitiveservices account show -g $RESOURCE_GROUP -n $OPENAI_RESOURCE_NAME --query id -o tsv)
```

> NOTE: Replace placeholders with real values. Always prefer scoping the role narrowly to the target resource.

#### Environment Variables

Required:
* `VOICE_LIVE_MODEL` – Model deployment name or model identifier.
* `VOICE_LIVE_VOICE` – Voice configuration (e.g. `en-US-JennyNeural`).

Optional:
* `AZURE_VOICE_LIVE_ENDPOINT` – Websocket endpoint (default: `wss://api.voicelive.com/v1`).
* `VOICE_LIVE_INSTRUCTIONS` – System instructions for the assistant (default friendly helper text).
* `VOICE_LIVE_VERBOSE` – Any non-empty value enables verbose event logging.
* `AZURE_CLIENT_ID` – Client ID of a user-assigned managed identity (forces its selection in `DefaultAzureCredential`).
* `AZURE_LOG_LEVEL` – Set to `info`, `warning`, or `debug` for Azure SDK logs.

If required variables are missing the application returns an error state (`/status`).

#### Local Development

Login once with the Azure CLI:

```bash
az login
```

Then run:

```bash
VOICE_LIVE_MODEL="<model>" VOICE_LIVE_VOICE="<voice>" uv run web
```

#### Diagnostics

At startup the app attempts to fetch an access token for the `https://cognitiveservices.azure.com/.default` scope and logs success/failure (non-fatal). If you see a warning, verify role assignments and identity configuration.

