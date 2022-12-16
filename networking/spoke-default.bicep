targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('Deployment name used in naming')
@minLength(3)
@maxLength(8)
param deploymentName string

@description('Organization App ID e.g Business Unit (BU0001A0008)')
@minLength(5)
@maxLength(11)
param orgAppId string

@description('The regional hub network to which this regional spoke will peer to.')
param hubVnetResourceId string

@description('The spokes\'s regional affinity. All resources tied to this spoke will also be homed in this region. The network team maintains this approved regional list which is a subset of zones with Availability Zone support.')
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
param spokeLocation string

@description('The hub regional affinity.')
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
param hubLocation string

@description('The ip range for spoke network')
@minLength(3)
@maxLength(7)
param spokeIpPrefix string

/*** RESOURCES ***/

resource routeTable 'Microsoft.Network/routeTables@2020-05-01' = {
  name: 'route-to-${spokeLocation}-hub-fw'
  location: spokeLocation
  properties: {
    routes: [
      {
        name: 'r-nexthop-to-fw'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: reference(resourceId(split(hubVnetResourceId, '/')[4], 'Microsoft.Network/azureFirewalls', 'fw-${hubLocation}'), '2020-05-01').ipConfigurations[0].properties.privateIpAddress
        }
      }
    ]
  }
}

resource nsg_clusterVNetName_nodepools 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: 'nsg-vnet-spoke-${orgAppId}-00-nodepools'
  location: spokeLocation
  properties: {
    securityRules: []
  }
}

resource nsg_clusterVNetName_nodepools_Microsoft_Insights_toHub 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'toHub'
  properties: {
    workspaceId: resourceId(split(hubVnetResourceId, '/')[4], 'Microsoft.OperationalInsights/workspaces', 'la-hub-${hubLocation}-${uniqueString(hubVnetResourceId)}')
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
  scope: nsg_clusterVNetName_nodepools
}

resource nsg_clusterVNetName_aksilbs 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: 'nsg-vnet-spoke-${orgAppId}-00-aksilbs'
  location: spokeLocation
  properties: {
    securityRules: []
  }
}

resource nsg_clusterVNetName_aksilbs_Microsoft_Insights_toHub 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'toHub'
  properties: {
    workspaceId: resourceId(split(hubVnetResourceId, '/')[4], 'Microsoft.OperationalInsights/workspaces', 'la-hub-${hubLocation}-${uniqueString(hubVnetResourceId)}')
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
  scope: nsg_clusterVNetName_aksilbs
}

resource nsg_clusterVNetName_appgw 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: 'nsg-vnet-spoke-${orgAppId}-00-appgw'
  location: spokeLocation
  properties: {
    securityRules: [
      {
        name: 'Allow443InBound'
        properties: {
          description: 'Allow ALL web traffic into 443. (If you wanted to allow-list specific IPs, this is where you\'d list them.)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '443'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowControlPlaneInBound'
        properties: {
          description: 'Allow Azure Control Plane in. (https://docs.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '65200-65535'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHealthProbesInBound'
        properties: {
          description: 'Allow Azure Health Probes in. (https://docs.microsoft.com/azure/application-gateway/configuration-infrastructure#network-security-groups)'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationPortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow80InBound'
        properties: {
          description: 'Allow ALL web traffic into 80, mainly to allow HTTPS redirection. (If you wanted to allow-list specific IPs, this is where you\'d list them.)'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '80'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAllOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource nsg_clusterVNetName_appgw_Microsoft_Insights_toHub 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'toHub'
  properties: {
    workspaceId: resourceId(split(hubVnetResourceId, '/')[4], 'Microsoft.OperationalInsights/workspaces', 'la-hub-${hubLocation}-${uniqueString(hubVnetResourceId)}')
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
  scope: nsg_clusterVNetName_appgw
}

resource clusterVNet 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: 'vnet-spoke-${orgAppId}-00'
  location: spokeLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        '${spokeIpPrefix}.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'snet-clusternodes'
        properties: {
          addressPrefix: '${spokeIpPrefix}.0.0/22'
          routeTable: {
            id: routeTable.id
          }
          networkSecurityGroup: {
            id: nsg_clusterVNetName_nodepools.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-clusteringressservices'
        properties: {
          addressPrefix: '${spokeIpPrefix}.4.0/28'
          routeTable: {
            id: routeTable.id
          }
          networkSecurityGroup: {
            id: nsg_clusterVNetName_aksilbs.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-applicationgateway'
        properties: {
          addressPrefix: '${spokeIpPrefix}.4.16/28'
          networkSecurityGroup: {
            id: nsg_clusterVNetName_appgw.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource clusterVNetName_toHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-05-01' = {
  parent: clusterVNet
  name: 'spoke-to-${split(hubVnetResourceId, '/')[8]}'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnetResourceId
    }
    allowForwardedTraffic: false
    allowVirtualNetworkAccess: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource clusterVNetName_Microsoft_Insights_toHub 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'toHub'
  properties: {
    workspaceId: resourceId(split(hubVnetResourceId, '/')[4], 'Microsoft.OperationalInsights/workspaces', 'la-hub-${hubLocation}-${uniqueString(hubVnetResourceId)}')
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
  scope: clusterVNet
}

module CreateHubTo_clusterVNetName_Peer './nested_CreateHubTo_clusterVNetName_Peer.bicep' = {
  name: 'CreateHubTovnet-spoke-${orgAppId}-00Peer'
  scope: resourceGroup(split(hubVnetResourceId, '/')[4])
  params: {
    resourceId_Microsoft_Network_virtualNetworks_variables_clusterVNetName: clusterVNet.id
    variables_hubNetworkName: split(hubVnetResourceId, '/')[8]
    variables_clusterVNetName: 'vnet-spoke-${orgAppId}-00'
  }
  dependsOn: [
    clusterVNetName_toHubPeering
  ]
}

resource primaryClusterPip 'Microsoft.Network/publicIpAddresses@2020-05-01' = {
  name: 'pip-${deploymentName}-${orgAppId}-00'
  location: spokeLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}

output clusterVnetResourceId string = clusterVNet.id
output nodepoolSubnetResourceIds array = [
  resourceId('Microsoft.Network/virtualNetworks/subnets', 'vnet-spoke-${orgAppId}-00', 'snet-clusternodes')
]
output appGwPublicIpAddress string = primaryClusterPip.properties.ipAddress
