targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Short prefix used in resource names.')
@minLength(3)
@maxLength(12)
param prefix string = 'rickmorty'

var suffix = uniqueString(subscription().subscriptionId, resourceGroup().id)
var acrName = toLower('${prefix}${suffix}')
var environmentName = '${prefix}-env'
var identityName = '${prefix}-acr-pull'
var acrPullRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource pullIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

resource registryPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, pullIdentity.principalId, acrPullRoleDefinitionId)
  scope: registry
  properties: {
    principalId: pullIdentity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: acrPullRoleDefinitionId
  }
}

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
}

output acrName string = registry.name
output acrLoginServer string = registry.properties.loginServer
output environmentName string = environment.name
output identityName string = pullIdentity.name
output identityResourceId string = pullIdentity.id

