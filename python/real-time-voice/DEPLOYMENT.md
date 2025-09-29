# GPT Realtime Model Deployment for Student Experimentation

This template provisions **ONLY the AI model** students need to experiment with GPT realtime. 

## Architecture

- **Azure AI Foundry** - Modern AI services with GPT realtime model deployed
- **Local Flask App** - Students run this locally, connecting to the deployed model

## Prerequisites

- [Azure Developer CLI (azd)](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Azure subscription with OpenAI access
- Python 3.9+

## Quick Start - Provision AI Resources Only

1. **Initialize environment** (choose a descriptive name):
   ```bash
   azd env new gpt-realtime-lab --confirm
   # or: azd env new your-name-gpt-experiment --confirm
   ```
   
   **Important**: This name becomes part of your Azure resource names!  
   The `--confirm` flag sets this as your default environment without prompting.

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

- **Azure AI Foundry** - Modern AI services resource
- **GPT Realtime Model** - Deployed and ready to use
- **No extra dependencies** - No projects, storage, or other complex setup needed

## Environment Variables

After deployment, these variables are available in your environment:

- `AZUREAI_FOUNDRY_NAME` - Name of the AI Foundry resource
- `AZURE_OPENAI_ENDPOINT` - AI Foundry endpoint for the model
- `AZURE_OPENAI_API_KEY` - Access key for the model
- `AZURE_OPENAI_REALTIME_MODEL_NAME` - Deployed model name (gpt-realtime)

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

### Missing model quota
- Ensure your Azure subscription has AI Foundry access enabled
- Check quota availability for GPT Realtime in your region

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