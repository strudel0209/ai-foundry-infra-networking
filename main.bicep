@description('Location for resources')
param location string = resourceGroup().location

// Resource names
param aiSearchName string
param aiOpenAIName string
param storageAccountName string
param blobPrivateEndpointName string

// Add parameter for the second storage account name
param storageAccountName2 string

// Principal IDs (Azure AD Object IDs of service principals or managed identities)
param aiSearchPrincipalId string
param aiOpenAIPrincipalId string
param aiFoundryProjectPrincipalId string

// Add developer's Azure AD Object ID
param developerPrincipalId string

// Built-in Role Definition IDs (verified from Azure documentation)
var roles = {
  searchIndexDataContributor: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  searchIndexDataReader: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
  searchServiceContributor: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  cognitiveServicesContributor: '25fbc0a9-bd7c-42a3-aa1a-3b75d497ee68'
  cognitiveServicesOpenAIContributor: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  storageFileDataPrivilegedContributor: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
}

// Existing resources
resource aiSearch 'Microsoft.Search/searchServices@2023-11-01' existing = {
  name: aiSearchName
}

resource aiOpenAI 'Microsoft.CognitiveServices/accounts@2023-10-01' existing = {
  name: aiOpenAIName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource blobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' existing = {
  name: blobPrivateEndpointName
}

// Reference existing second storage account
resource storageAccount2 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName2
}

// Role Assignments
resource roleAssignment1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiSearch.id, aiOpenAIPrincipalId, roles.searchIndexDataContributor)
  scope: aiSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.searchIndexDataContributor)
    principalId: aiOpenAIPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignment2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiSearch.id, aiOpenAIPrincipalId, roles.searchIndexDataReader)
  scope: aiSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.searchIndexDataReader)
    principalId: aiOpenAIPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignment3 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiSearch.id, aiOpenAIPrincipalId, roles.searchServiceContributor)
  scope: aiSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.searchServiceContributor)
    principalId: aiOpenAIPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignment4 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiOpenAI.id, aiSearchPrincipalId, roles.cognitiveServicesContributor)
  scope: aiOpenAI
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.cognitiveServicesContributor)
    principalId: aiSearchPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignment5 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiOpenAI.id, aiSearchPrincipalId, roles.cognitiveServicesOpenAIContributor)
  scope: aiOpenAI
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.cognitiveServicesOpenAIContributor)
    principalId: aiSearchPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignment6 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, aiSearchPrincipalId, roles.storageBlobDataContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: aiSearchPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignment7 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, aiOpenAIPrincipalId, roles.storageBlobDataContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: aiOpenAIPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignment8 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(blobPrivateEndpoint.id, aiFoundryProjectPrincipalId, roles.reader)
  scope: blobPrivateEndpoint
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.reader)
    principalId: aiFoundryProjectPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Additional role assignments for Developer
resource roleAssignmentDeveloperAIsearchContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiSearch.id, developerPrincipalId, roles.searchServiceContributor)
  scope: aiSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.searchServiceContributor)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

resource roleAssignmentDeveloperAIsearchIndexContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiSearch.id, developerPrincipalId, roles.searchIndexDataContributor)
  scope: aiSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.searchIndexDataContributor)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

resource roleAssignmentDeveloperOpenAIContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiOpenAI.id, developerPrincipalId, roles.cognitiveServicesOpenAIContributor)
  scope: aiOpenAI
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.cognitiveServicesOpenAIContributor)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

resource roleAssignmentDeveloperCognitiveContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiOpenAI.id, developerPrincipalId, roles.cognitiveServicesContributor)
  scope: aiOpenAI
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.cognitiveServicesContributor)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

resource roleAssignmentDeveloperOpenAIResourceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiOpenAI.id, developerPrincipalId, roles.contributor)
  scope: aiOpenAI
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.contributor)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

resource roleAssignmentDeveloperStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, developerPrincipalId, roles.contributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.contributor)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

resource roleAssignmentDeveloperStorageBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, developerPrincipalId, roles.storageBlobDataContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

resource roleAssignmentDeveloperStorageFilePrivilegedContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, developerPrincipalId, roles.storageFileDataPrivilegedContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageFileDataPrivilegedContributor)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

// Assign same roles to developer for second storage account
resource roleAssignmentDeveloperStorageContributor2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount2.id, developerPrincipalId, roles.contributor)
  scope: storageAccount2
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.contributor)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

resource roleAssignmentDeveloperStorageBlobContributor2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount2.id, developerPrincipalId, roles.storageBlobDataContributor)
  scope: storageAccount2
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

resource roleAssignmentDeveloperStorageFilePrivilegedContributor2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount2.id, developerPrincipalId, roles.storageFileDataPrivilegedContributor)
  scope: storageAccount2
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageFileDataPrivilegedContributor)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}

// Role assignment at resource group scope for web app deployment
resource roleAssignmentDeveloperRGContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, developerPrincipalId, roles.contributor)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.contributor)
    principalId: developerPrincipalId
    principalType: 'User'
  }
}
