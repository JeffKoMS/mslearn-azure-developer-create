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

// Create Key Vault for storing secrets
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'kv-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        objectId: principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: ['get', 'list', 'set']
        }
      }
    ]
    enableRbacAuthorization: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false
  }
}

// Create Application Insights for monitoring
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ai-${resourceToken}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

// Create Storage Account for AI Hub
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'st${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// Create Container Registry for AI Hub
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  name: 'cr${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// Create AI Hub (AI Services multi-service account)
resource aiHub 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: 'aih-${resourceToken}'
  location: location
  tags: union(tags, {
    'azd-service-name': 'gpt-realtime-model'
  })
  sku: {
    name: 'S0'
  }
  kind: 'AIHub'
  properties: {
    customSubDomainName: 'aih-${resourceToken}'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// Create AI Project within the Hub
resource aiProject 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: 'aip-${resourceToken}'
  location: location
  tags: union(tags, {
    'azd-service-name': 'gpt-realtime-model'
  })
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'GPT Realtime Project'
    description: 'AI Project for GPT realtime model deployment'
    keyVault: keyVault.id
    storageAccount: storageAccount.id
    applicationInsights: applicationInsights.id
    containerRegistry: containerRegistry.id
    hubResourceId: aiHub.id
    publicNetworkAccess: 'Enabled'
  }
}

// Role assignments for the principal
resource cognitiveServicesContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68' // Cognitive Services Contributor
}

resource aiHubRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiHub
  name: guid(aiHub.id, principalId, cognitiveServicesContributor.id)
  properties: {
    roleDefinitionId: cognitiveServicesContributor.id
    principalId: principalId
    principalType: principalType
  }
}

// Outputs
output hubName string = aiHub.name
output projectName string = aiProject.name
output hubEndpoint string = aiHub.properties.endpoint
output projectId string = aiProject.id