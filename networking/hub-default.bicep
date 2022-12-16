targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The hub\'s regional affinity. All resources tied to this hub will also be homed in this region.  The network team maintains this approved regional list which is a subset of zones with Availability Zone support.')
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

@description('A /24 to contain the regional firewall, management, and gateway subnet')
@minLength(10)
@maxLength(18)
param hubVnetAddressSpace string = '10.200.0.0/24'

@description('A /26 under the VNet Address Space for the regional Azure Firewall')
@minLength(10)
@maxLength(18)
param azureFirewallSubnetAddressSpace string = '10.200.0.0/26'

@description('A /27 under the VNet Address Space for our regional On-Prem Gateway')
@minLength(10)
@maxLength(18)
param azureGatewaySubnetAddressSpace string = '10.200.0.64/27'

@description('A /27 under the VNet Address Space for regional Azure Bastion')
@minLength(10)
@maxLength(18)
param azureBastionSubnetAddressSpace string = '10.200.0.96/27'

@description('A /28 under the VNet Address Space for ACR')
@minLength(10)
@maxLength(18)
param azureCommonServicesSubnetAddressSpace string = '10.200.0.128/28'

var hubFwPipNames = [
  'pip-fw-${location}-default'
  'pip-fw-${location}-01'
  'pip-fw-${location}-02'
]

/*** RESOURCES ***/

// This Log Analytics workspace stores logs from the regional hub network, its spokes, and bastion.
// Log analytics is a regional resource, as such there will be one workspace per hub (region)
resource hubLa 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: 'la-hub-${location}-${uniqueString(hubVnet.id)}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource bastionNetworkNsg 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: 'nsg-${location}-bastion'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowWebExperienceInBound'
        properties: {
          description: 'Allow our users in. Update this to be as restrictive as possible.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowControlPlaneInBound'
        properties: {
          description: 'Service Requirement. Allow control plane access. Regional Tag not yet supported.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHealthProbesInBound'
        properties: {
          description: 'Service Requirement. Allow Health Probes.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostToHostInBound'
        properties: {
          description: 'Service Requirement. Allow Required Host to Host Communication.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
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
        name: 'AllowSshToVnetOutBound'
        properties: {
          description: 'Allow SSH out to the VNet'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '22'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowRdpToVnetOutBound'
        properties: {
          protocol: 'Tcp'
          description: 'Allow RDP out to the VNet'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '3389'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowControlPlaneOutBound'
        properties: {
          description: 'Required for control plane outbound. Regional prefix not yet supported'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionHostToHostOutBound'
        properties: {
          description: 'Service Requirement. Allow Required Host to Host Communication.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionCertificateValidationOutBound'
        properties: {
          description: 'Service Requirement. Allow Required Session and Certificate Validation.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '80'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyAllOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

// 2017-05-01-preview

resource bastionNetworkNsgName_Microsoft_Insights_default 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'default'
  properties: {
    workspaceId: hubLa.id
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
  scope: bastionNetworkNsg
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: 'vnet-${location}-hub'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: azureFirewallSubnetAddressSpace
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: azureGatewaySubnetAddressSpace
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: azureBastionSubnetAddressSpace
          networkSecurityGroup: {
            id: bastionNetworkNsg.id
          }
        }
      }
      {
        name: 'CommonServicesSubnet'
        properties: {
          addressPrefix: azureCommonServicesSubnetAddressSpace
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource hubVnetName_Microsoft_Insights_default 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'default'
  properties: {
    workspaceId: hubLa.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
  scope: hubVnet
}

resource hubFwPips 'Microsoft.Network/publicIpAddresses@2020-05-01' = [for item in hubFwPipNames: {
  name: item
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}]

resource fwPoliciesBase 'Microsoft.Network/firewallPolicies@2020-11-01' = {
  name: 'fw-policies-base'
  location: location
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Deny'
    threatIntelWhitelist: {
      ipAddresses: []
    }
    dnsSettings: {
      servers: []
      enableProxy: true
    }
  }
}

resource fwPoliciesBaseName_DefaultNetworkRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-11-01' = {
  parent: fwPoliciesBase
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'DNS'
            ipProtocols: [
              'UDP'
            ]
            sourceAddresses: [
              '*'
            ]
            sourceIpGroups: []
            destinationAddresses: [
              '*'
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '53'
            ]
          }
        ]
        name: 'org-wide-allowed'
        priority: 100
      }
    ]
  }
}

resource fwPolicies 'Microsoft.Network/firewallPolicies@2020-11-01' = {
  name: 'fw-policies-${location}'
  location: location
  properties: {
    basePolicy: {
      id: fwPoliciesBase.id
    }
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Deny'
    threatIntelWhitelist: {
      ipAddresses: []
    }
    dnsSettings: {
      servers: []
      enableProxy: true
    }
  }
  dependsOn: [

    fwPoliciesBaseName_DefaultNetworkRuleCollectionGroup
  ]
}

resource fwPoliciesName_DefaultDnatRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-11-01' = {
  parent: fwPolicies
  name: 'DefaultDnatRuleCollectionGroup'
  properties: {
    priority: 100
    ruleCollections: []
  }
}

resource fwPoliciesName_DefaultApplicationRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-11-01' = {
  parent: fwPolicies
  name: 'DefaultApplicationRuleCollectionGroup'
  properties: {
    priority: 300
    ruleCollections: []
  }
  dependsOn: [

    fwPoliciesName_DefaultDnatRuleCollectionGroup
  ]
}

resource fwPoliciesName_DefaultNetworkRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-11-01' = {
  parent: fwPolicies
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: []
  }
  dependsOn: [

    fwPoliciesName_DefaultApplicationRuleCollectionGroup
  ]
}

resource hubFw 'Microsoft.Network/azureFirewalls@2020-11-01' = {
  name: 'fw-${location}'
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    additionalProperties: {
    }
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Deny'
    ipConfigurations: [
      {
        name: hubFwPipNames[0]
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', 'vnet-${location}-hub', 'AzureFirewallSubnet')
          }
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIpAddresses', hubFwPipNames[0])
          }
        }
      }
      {
        name: hubFwPipNames[1]
        properties: {
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIpAddresses', hubFwPipNames[1])
          }
        }
      }
      {
        name: hubFwPipNames[2]
        properties: {
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIpAddresses', hubFwPipNames[2])
          }
        }
      }
    ]
    natRuleCollections: []
    networkRuleCollections: []
    applicationRuleCollections: []
    firewallPolicy: {
      id: fwPolicies.id
    }
  }
  dependsOn: [
    hubFwPips
    hubVnet
    fwPoliciesName_DefaultNetworkRuleCollectionGroup
  ]
}

resource hubFwName_Microsoft_Insights_default 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'default'
  properties: {
    workspaceId: hubLa.id
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
  scope: hubFw
}

output hubVnetId string = hubVnet.id
