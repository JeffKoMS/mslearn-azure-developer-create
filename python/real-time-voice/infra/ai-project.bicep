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

@description('Principal type for role assignments')
param principalType string

// Create minimal AI Foundry project - students will use the OpenAI endpoint directly
resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: 'ai-project-${resourceToken}'
  location: location
  tags: union(tags, {
    'azd-service-name': 'gpt-realtime-model'
  })
  sku: {
    name: 'Basic'
    tier: 'Basic'  
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'GPT Realtime Experiment Project'
    description: 'AI Foundry project for students to experiment with GPT realtime model'
    publicNetworkAccess: 'Enabled'
    v1LegacyMode: false
  }
}

// Role assignments for the principal to access the project
resource cognitiveServicesContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68' // Cognitive Services Contributor
}

resource aiProjectRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiProject
  name: guid(aiProject.id, principalId, cognitiveServicesContributor.id)
  properties: {
    roleDefinitionId: cognitiveServicesContributor.id
    principalId: principalId
    principalType: principalType
  }
}

// Outputs
output projectName string = aiProject.name
output projectId string = aiProject.id