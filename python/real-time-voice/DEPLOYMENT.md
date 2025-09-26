# GPT Realtime AI Resources for Student Experimentation

This template provisions **ONLY the AI resources** students need to experiment with GPT realtime models. The Flask application runs locally.

## Architecture

- **Azure AI Foundry Project** - Workspace for AI experimentation  
- **OpenAI Service** - With GPT realtime model deployed
- **Local Flask App** - Students run this locally, connecting to Azure OpenAI

## Prerequisites

- [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Azure subscription with OpenAI access
- Python 3.9+

## Quick Start - Provision AI Resources Only

1. **Initialize environment** (choose a descriptive name):
   ```bash
   azd env new gpt-realtime-lab
   # or: azd env new your-name-gpt-experiment
   ```
   
   **Important**: This name becomes part of your Azure resource names!

2. **Set your resource group** (optional):
   ```bash
   azd env set AZURE_RESOURCE_GROUP "rg-your-name-gpt"
   ```

3. **Login and provision AI resources**:
   ```bash
   az login
   azd provision
   ```

**Important**: Do NOT run `azd deploy` - there is no application to deploy!

## What gets created

The `infra/` folder contains minimal Bicep templates that provision:

- **Azure AI Foundry Project** - Minimal project for student experimentation
- **OpenAI Service** - With GPT realtime model deployed
- **No extra services** - No Key Vault, Storage, or Container Registry needed

## Environment Variables

After deployment, these variables are available in your environment:

- `AZUREAI_PROJECT_NAME` - Name of the AI Foundry Project
- `AZUREAI_PROJECT_ID` - Full resource ID of the project
- `AZURE_OPENAI_ENDPOINT` - OpenAI service endpoint
- `AZURE_OPENAI_API_KEY` - OpenAI service API key
- `AZURE_OPENAI_REALTIME_MODEL_NAME` - Deployed model name

## Running the Local Flask Application

After provisioning, configure your local Flask app with the Azure OpenAI details:

```bash
export AZURE_VOICE_LIVE_ENDPOINT="<from azd output>"
export AZURE_VOICE_LIVE_API_KEY="<from azd output>"  
export VOICE_LIVE_MODEL="gpt-realtime"
```

Then run the Flask app locally:
```bash
cd src/real_time_voice
python flask_app.py
```

## Troubleshooting

### Deployment fails with "resource not found"
- Ensure `azd provision` completed successfully before running `azd deploy`
- Check that resources are tagged with `azd-service-name: gpt-realtime-model`

### Missing OpenAI quota
- Ensure your Azure subscription has OpenAI access enabled
- Check quota availability for GPT-4o Realtime Preview in your region

### Permission errors
- Ensure you have Contributor access to the subscription/resource group
- Role assignments are created automatically for the authenticated user

## Commands Reference

```bash
# Environment management
azd env new <name>              # Create new environment
azd env list                    # List environments
azd env select <name>           # Switch environments

# AI Resource provisioning
azd provision                   # Provision AI resources only
azd down                        # Delete all resources

# DO NOT USE:
# azd deploy                    # Not applicable - no app deployment
# azd up                        # Use azd provision instead

# Monitoring
azd monitor                     # Open Azure Portal for resources
```

## Next Steps

1. **Customize the Flask app** - Modify `src/real_time_voice/` for your use case
2. **Add features** - Extend with additional AI capabilities
3. **Set up CI/CD** - Use `azd pipeline config` for automated deployments
4. **Monitor usage** - Check Azure Monitor and Application Insights