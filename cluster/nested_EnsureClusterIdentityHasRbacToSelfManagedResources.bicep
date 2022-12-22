targetScope = 'resourceGroup'

/*** PARAMETERS ***/

param resourceId_Microsoft_ManagedIdentity_userAssignedIdentities_variables_clusterControlPlaneIdentityName object
param variables_vnetNodePoolSubnetResourceId string
param variables_networkContributorRole string
param variables_clusterControlPlaneIdentityName string
param variables_vnetName string
param variables_vnetIngressServicesSubnetResourceId string

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

/*** EXISTING HUB RESOURCES ***/

resource targetVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: variables_vnetName
}

resource snetClusterNodes 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  parent: targetVirtualNetwork
  name: 'snet-clusternodes'
}

resource snetClusterIngress 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  parent: targetVirtualNetwork
  name: 'snet-clusteringressservices'
}

/*** RESOURCES ***/

resource variables_vnetNodePoolSubnetResourceId_variables_networkContributorRole_variables_clusterControlPlaneIdentityName_location 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: snetClusterNodes
  name: guid(variables_vnetNodePoolSubnetResourceId, variables_networkContributorRole, variables_clusterControlPlaneIdentityName, location)
  properties: {
    roleDefinitionId: variables_networkContributorRole
    description: 'Allows cluster identity to join the nodepool vmss resources to this subnet.'
    principalId: resourceId_Microsoft_ManagedIdentity_userAssignedIdentities_variables_clusterControlPlaneIdentityName.principalId
    principalType: 'ServicePrincipal'
  }
}

resource variables_vnetIngressServicesSubnetResourceId_variables_networkContributorRole_variables_clusterControlPlaneIdentityName_location 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: snetClusterIngress
  name: guid(variables_vnetIngressServicesSubnetResourceId, variables_networkContributorRole, variables_clusterControlPlaneIdentityName, location)
  properties: {
    roleDefinitionId: variables_networkContributorRole
    description: 'Allows cluster identity to join load balancers (ingress resources) to this subnet.'
    principalId: resourceId_Microsoft_ManagedIdentity_userAssignedIdentities_variables_clusterControlPlaneIdentityName.principalId
    principalType: 'ServicePrincipal'
  }
}
