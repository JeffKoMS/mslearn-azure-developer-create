# GPT Realtime Voice Application with Azure AI Foundry

This application demonstrates real-time voice interaction using OpenAI's GPT-4o Realtime model deployed on Azure AI Foundry.

## Architecture

The solution includes:

- **Flask Application** (`src/real_time_voice/`) - Web interface for voice interaction
- **Azure Infrastructure** (`infra/`) - Bicep templates for Azure AI resources
- **Azure Developer CLI** - Automated provisioning and deployment

## Prerequisites

- [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Azure subscription with OpenAI access
- Python 3.9+

## Quick Start

### Option 1: Use this template (with infrastructure)

1. **Clone and initialize**:
   ```bash
   # If starting from this repository
   azd env new <your-environment-name>
   ```

2. **Set your resource group** (optional):
   ```bash
   azd env set AZURE_RESOURCE_GROUP "rg-your-name-gpt"
   ```

3. **Login and deploy**:
   ```bash
   az login
   azd up
   ```

### Option 2: Use the official Azure AI Foundry starter (recommended for beginners)

```bash
azd init -t Azure-Samples/azd-aistudio-starter
azd up
```

## What gets created

The `infra/` folder contains Bicep templates that provision:

- **Azure AI Hub** - Central workspace for AI projects
- **Azure AI Project** - Project container for models and deployments  
- **OpenAI Service** - With GPT-4o Realtime Preview model deployed
- **Supporting services** - Key Vault, Storage Account, Container Registry
- **Proper tagging** - All resources tagged for azd service discovery

## Environment Variables

After deployment, these variables are available in your environment:

- `AZUREAI_HUB_NAME` - Name of the AI Hub
- `AZUREAI_PROJECT_NAME` - Name of the AI Project
- `AZURE_OPENAI_ENDPOINT` - OpenAI service endpoint
- `AZURE_OPENAI_API_KEY` - OpenAI service API key
- `AZURE_OPENAI_REALTIME_MODEL_NAME` - Deployed model name

## Running the Application

The Flask application will be automatically configured to use the deployed Azure OpenAI service. Set the required environment variables in your Flask app:

```bash
export AZURE_VOICE_LIVE_ENDPOINT="<from azd output>"
export AZURE_VOICE_LIVE_API_KEY="<from azd output>"
export VOICE_LIVE_MODEL="gpt-4o-realtime-preview"
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

# Deployment
azd up                          # Provision + deploy everything
azd provision                   # Provision infrastructure only
azd deploy                      # Deploy application only
azd down                        # Delete all resources

# Monitoring
azd monitor                     # Open Azure Portal for resources
```

## Next Steps

1. **Customize the Flask app** - Modify `src/real_time_voice/` for your use case
2. **Add features** - Extend with additional AI capabilities
3. **Set up CI/CD** - Use `azd pipeline config` for automated deployments
4. **Monitor usage** - Check Azure Monitor and Application Insights