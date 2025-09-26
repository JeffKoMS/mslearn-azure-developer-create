@description('Primary location for all resources')
param location string

@description('Name of the environment used to derive resource names')
param environmentName string

@description('Unique token for resource naming')
param resourceToken string

@description('Tags to apply to resources')
param tags object = {}

@description('Principal ID for role assignments')
param principalId string

// Create OpenAI service
resource openaiService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: 'openai-${resourceToken}'
  location: location
  tags: union(tags, {
    'azd-service-name': 'gpt-realtime-model'
  })
  sku: {
    name: 'S0'
  }
  kind: 'OpenAI'
  properties: {
    customSubDomainName: 'openai-${resourceToken}'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// Deploy GPT-4o Realtime Preview model
resource gptRealtimeDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openaiService
  name: 'gpt-4o-realtime-preview'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-realtime-preview'
      version: '2024-10-01'
    }
    raiPolicyName: 'Microsoft.Default'
  }
  sku: {
    name: 'Standard'
    capacity: 1
  }
}

// Role assignment for OpenAI service
resource cognitiveServicesOpenAIUser 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd' // Cognitive Services OpenAI User
}

resource openaiRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openaiService
  name: guid(openaiService.id, principalId, cognitiveServicesOpenAIUser.id)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAIUser.id
    principalId: principalId
    principalType: 'User'
  }
}

// Outputs
output endpoint string = openaiService.properties.endpoint
output apiKey string = openaiService.listKeys().key1
output realtimeModelName string = gptRealtimeDeployment.name
output openaiServiceName string = openaiService.name