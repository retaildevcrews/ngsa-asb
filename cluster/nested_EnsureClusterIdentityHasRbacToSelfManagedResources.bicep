param resourceId_Microsoft_ManagedIdentity_userAssignedIdentities_variables_clusterControlPlaneIdentityName object
param variables_vnetNodePoolSubnetResourceId ? /* TODO: fill in correct type */
param variables_networkContributorRole ? /* TODO: fill in correct type */
param variables_clusterControlPlaneIdentityName ? /* TODO: fill in correct type */
param variables_vnetName ? /* TODO: fill in correct type */
param variables_vnetIngressServicesSubnetResourceId ? /* TODO: fill in correct type */

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

resource variables_vnetNodePoolSubnetResourceId_variables_networkContributorRole_variables_clusterControlPlaneIdentityName_location 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: 'Microsoft.Network/virtualNetworks/${variables_vnetName}/subnets/snet-clusternodes'
  name: guid(variables_vnetNodePoolSubnetResourceId, variables_networkContributorRole, variables_clusterControlPlaneIdentityName, location)
  properties: {
    roleDefinitionId: variables_networkContributorRole
    description: 'Allows cluster identity to join the nodepool vmss resources to this subnet.'
    principalId: resourceId_Microsoft_ManagedIdentity_userAssignedIdentities_variables_clusterControlPlaneIdentityName.principalId
    principalType: 'ServicePrincipal'
  }
}

resource variables_vnetIngressServicesSubnetResourceId_variables_networkContributorRole_variables_clusterControlPlaneIdentityName_location 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: 'Microsoft.Network/virtualNetworks/${variables_vnetName}/subnets/snet-clusteringressservices'
  name: guid(variables_vnetIngressServicesSubnetResourceId, variables_networkContributorRole, variables_clusterControlPlaneIdentityName, location)
  properties: {
    roleDefinitionId: variables_networkContributorRole
    description: 'Allows cluster identity to join load balancers (ingress resources) to this subnet.'
    principalId: resourceId_Microsoft_ManagedIdentity_userAssignedIdentities_variables_clusterControlPlaneIdentityName.principalId
    principalType: 'ServicePrincipal'
  }
}