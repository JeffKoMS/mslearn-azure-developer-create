targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment used to derive resource names and tags.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string

@description('The type of principal (User or ServicePrincipal)')
@allowed(['User', 'ServicePrincipal'])  
param principalType string = 'User'

@description('Name of the resource group for the AI project resources')
param aiResourceGroupName string = ''

// Tags to apply to all resources
var tags = {
  'azd-env-name': environmentName
}

// Generate unique suffix for resource names
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Create resource group for AI resources
resource aiResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(aiResourceGroupName) ? aiResourceGroupName : 'rg-${environmentName}'
  location: location
  tags: tags
}

// Deploy AI Hub and Project resources
module aiHub 'ai-hub.bicep' = {
  name: 'ai-hub'
  scope: aiResourceGroup
  params: {
    location: location
    environmentName: environmentName
    resourceToken: resourceToken
    tags: tags
    principalId: principalId
    principalType: principalType
  }
}

// Deploy OpenAI service with GPT Realtime model
module openai 'openai.bicep' = {
  name: 'openai'
  scope: aiResourceGroup
  params: {
    location: location
    environmentName: environmentName
    resourceToken: resourceToken
    tags: tags
    principalId: principalId
  }
}

// Outputs for azd environment variables
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = aiResourceGroup.name

// AI-specific outputs
output AZUREAI_HUB_NAME string = aiHub.outputs.hubName
output AZUREAI_PROJECT_NAME string = aiHub.outputs.projectName
output AZUREAI_RESOURCE_GROUP_NAME string = aiResourceGroup.name

// OpenAI outputs
output AZURE_OPENAI_ENDPOINT string = openai.outputs.endpoint
output AZURE_OPENAI_API_KEY string = openai.outputs.apiKey
output AZURE_OPENAI_REALTIME_MODEL_NAME string = openai.outputs.realtimeModelName