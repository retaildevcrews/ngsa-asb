targetScope = 'resourceGroup'

/*** PARAMETERS ***/

param resourceId_Microsoft_ContainerService_managedClusters_variables_clusterName object
param variables_virtualMachineContributorRole string

@description('AKS Service, Node Pool, and supporting services (KeyVault, App Gateway, etc) region. This needs to be the same region as the vnet provided in these parameters.')
@allowed([
  'australiaeast'
  'canadacentral'
  'centralus'
  'eastus'
  'eastus2'
  'westus2'
  'westus3'
  'northcentralus'
  'francecentral'
  'germanywestcentral'
  'northeurope'
  'southafricanorth'
  'southcentralus'
  'uksouth'
  'westeurope'
  'japaneast'
  'southeastasia'
])
param location string

/*** RESOURCES ***/

resource id_name_location 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = {
  name: guid(resourceGroup().id, deployment().name, location)
  properties: {
    roleDefinitionId: variables_virtualMachineContributorRole
    principalId: resourceId_Microsoft_ContainerService_managedClusters_variables_clusterName.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}
