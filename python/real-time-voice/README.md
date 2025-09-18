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

Grant the container's system-assigned Managed Identity appropriate data-plane access to your Azure OpenAI (or Voice Live) resource. Typically you need:

* Cognitive Services OpenAI User (built-in role) – allows calling inference endpoints.
* If logging to other Azure resources (e.g., Blob, App Insights) grant those respective Data Reader/Contributor roles as needed.

This setup uses ONLY a system-assigned managed identity for simplicity.

#### Required Role Assignments

Assign the role at the scope of the specific Cognitive Services / Azure OpenAI resource (least privilege) or, if needed, the resource group.

```bash
# Variables
rg="<rg-name>"
openai_resource_name="<azure-openai-resource>"   # Your Azure OpenAI / Cognitive Services resource name
aci_name="<aci-name>"

# After deploying (or re-deploying) the container with --assign-identity:
aci_principal_id=$(az container show -g $rg -n $aci_name --query identity.principalId -o tsv)
az role assignment create \
  --assignee $aci_principal_id \
  --role "Cognitive Services OpenAI User" \
  --scope $(az cognitiveservices account show -g $rg -n $openai_resource_name --query id -o tsv)
```

> NOTE: Replace placeholders with real values. Always prefer scoping the role narrowly to the target resource.

### Deployment (ACI + System-Assigned Managed Identity)

The provided `azdeploy.sh` builds and deploys the container with ACR admin credentials. To enable identity-based access to Azure OpenAI using the simpler system-assigned managed identity (SAMI), add the identity at deployment time and assign the Cognitive Services role.

#### 1. Add System-Assigned Identity on (Re)Create
If the container already exists, delete and recreate with `--assign-identity`:
```bash
az container delete -g $rg -n aci-realtimevoice --yes

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
```

#### 2. Retrieve Principal ID
```bash
aci_principal_id=$(az container show -g $rg -n aci-realtimevoice --query identity.principalId -o tsv)
```

#### 3. Assign Roles
```bash
openai_id=$(az cognitiveservices account show -g $rg -n rtv-exercise-resource --query id -o tsv)

az role assignment create \
	--assignee $aci_principal_id \
	--role "Cognitive Services OpenAI User" \
	--scope $openai_id
```

Optional (remove ACR admin creds later and rely on MI for pulls):
```bash
acr_id=$(az acr show -g $rg -n $acr_name --query id -o tsv)
az role assignment create \
	--assignee $aci_principal_id \
	--role "AcrPull" \
	--scope $acr_id
```

Recreate without registry username/password once AcrPull propagates:
```bash
az container delete -g $rg -n aci-realtimevoice --yes
az container create -g $rg -n aci-realtimevoice \
	--image $acr_image \
	--assign-identity \
	--ports 5000 \
	--environment-variables "${env_vars[@]}" \
	--location $location \
	--dns-name-label $dns_label \
	--os-type Linux \
	--cpu 1 \
	--memory 1.5
```

#### 4. Verify Auth
```bash
az container logs -g $rg -n aci-realtimevoice --tail 100
```
Look for the token acquisition success log. Role assignment propagation can take ~60s.

#### Environment Variables

Required:
* `VOICE_LIVE_MODEL` – Model deployment name or model identifier.
* `VOICE_LIVE_VOICE` – Voice configuration (e.g. `en-US-JennyNeural`).

Optional:
* `AZURE_VOICE_LIVE_ENDPOINT` – Websocket endpoint (default: `wss://api.voicelive.com/v1`).
* `VOICE_LIVE_INSTRUCTIONS` – System instructions for the assistant (default friendly helper text).
* `VOICE_LIVE_VERBOSE` – Any non-empty value enables verbose event logging.
* `AZURE_CLIENT_ID` – Not required (only needed if you later adopt a user-assigned identity).
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

