@description('Deployment name used in naming')
@minLength(3)
@maxLength(8)
param deploymentName string

@description('Log Analytics Workspace Name to Use')
@minLength(0)
@maxLength(24)
param laWorkspaceName string = ''

@description('Resource Group where Log Analytics is')
@minLength(0)
@maxLength(24)
param laResourceGroup string = ''

@description('Resource group prefix used to create the nodepools resource group')
param nodepoolsRGName string

@description('Organization App ID e.g Business Unit (BU0001A0008)')
@minLength(5)
@maxLength(11)
param orgAppId string

@description('DNS name used in private DNS Zone')
@minLength(3)
param asbDnsName string

@description('The regional network spoke VNet Resource ID that the cluster will be joined to')
@minLength(79)
param targetVnetResourceId string

@description('The hub network VNet Resource ID')
@minLength(79)
param hubVnetResourceId string

@description('Azure AD Group in the identified tenant that will be granted the highly privileged cluster-admin role.')
param clusterAdminAadGroupObjectId string

@description('Your AKS control plane Cluster API authentication tenant')
param k8sControlPlaneAuthorizationTenantId string

@description('The certificate data for app gateway TLS termination. It is base64')
param appGatewayListenerCertificate string

@description('The AKS Ingress Controller public certificate (as .crt or .cer) to be stored in Azure Key Vault as secret and referenced by the AKS ingress controller.')
param aksIngressControllerCertificate string

@description('The AKS Ingress Controller private certificate key to be stored in Azure Key Vault as secret and referenced by the AKS ingress controller.')
param aksIngressControllerKey string

@description('IP ranges authorized to contact the Kubernetes API server. Passing an empty array will result in no IP restrictions. If any are provided, remember to also provide the public IP of the egress Azure Firewall otherwise your nodes will not be able to talk to the API server (e.g. Flux).')
param clusterAuthorizedIPRanges array = []

@description('Top level domain suffix')
@minLength(3)
@maxLength(128)
param asbDomainSuffix string

@description('DNS Zone')
@minLength(3)
@maxLength(128)
param asbDnsZone string

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

@description('For Azure resources that support native geo-redunancy, provide the location the redundant service will have its secondary. Should be different than the location parameter and ideally should be a paired region - https://docs.microsoft.com/azure/best-practices-availability-paired-regions. This region does not need to support availability zones.')
@allowed([
  'australiasoutheast'
  'canadaeast'
  'eastus2'
  'westus'
  'centralus'
  'westcentralus'
  'francesouth'
  'germanynorth'
  'westeurope'
  'ukwest'
  'northeurope'
  'japanwest'
  'southafricawest'
  'northcentralus'
  'eastasia'
  'eastus'
  'westus2'
  'westus3'
  'francecentral'
  'uksouth'
  'japaneast'
  'southeastasia'
])
param geoRedundancyLocation string
param kubernetesVersion string = '1.20.9'

var networkContributorRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'
var monitoringMetricsPublisherRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/3913510d-42f4-4e42-8a64-420c390055eb'
var acrPullRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d'
var managedIdentityOperatorRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/f1a07417-d97a-45cb-824c-7a7467783830'
var virtualMachineContributorRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
var readerRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7'
var subRgUniqueString = uniqueString('aks', subscription().subscriptionId, resourceGroup().id)
var nodeResourceGroupName = 'rg-${nodepoolsRGName}-nodepools-${location}'
var baseName = 'aks-${subRgUniqueString}'
var clusterName = '${baseName}-${location}'
var laNewWorkspaceName = 'la-${baseName}'
var logAnalyticsWorkspaceName = ((empty(laWorkspaceName) && empty(laResourceGroup)) ? laNewWorkspaceName : ((!(empty(laWorkspaceName) || empty(laResourceGroup))) ? laWorkspaceName : null))
var isNewLogAnalytics = (logAnalyticsWorkspaceName == laNewWorkspaceName)
var logAnalyticsResourceGroup = (isNewLogAnalytics ? resourceGroup().name : laResourceGroup)
var containerInsightsSolutionName = 'ContainerInsights(${logAnalyticsWorkspaceName})'
var defaultAcrName = 'acraks${subRgUniqueString}'
var vNetResourceGroup = split(targetVnetResourceId, '/')[4]
var vnetName = split(targetVnetResourceId, '/')[8]
var vnetNodePoolSubnetResourceId = '${targetVnetResourceId}/subnets/snet-clusternodes'
var vnetIngressServicesSubnetResourceId = '${targetVnetResourceId}/subnets/snet-cluster-ingressservices'
var vnetHubCommonServicesSubnetResourceId = '${hubVnetResourceId}/subnets/CommonServicesSubnet'
var HubvnetName = split(hubVnetResourceId, '/')[8]
var agwName = 'apw-${clusterName}'
var apwResourceId = agw.id
var acrPrivateDnsZonesName = 'privatelink.azurecr.io'
var akvPrivateDnsZonesName = 'privatelink.vaultcore.azure.net'
var clusterControlPlaneIdentityName = 'mi-${clusterName}-controlplane'
var keyVaultName = 'kv-${baseName}'
var policyResourceIdAKSLinuxRestrictive = '/providers/Microsoft.Authorization/policySetDefinitions/42b8ef37-b724-4e24-bbc8-7a7708edfe00'
var policyResourceIdEnforceHttpsIngress = '/providers/Microsoft.Authorization/policyDefinitions/1a5b4dca-0b6f-4cf5-907c-56316bc1bf3d'
var policyResourceIdEnforceInternalLoadBalancers = '/providers/Microsoft.Authorization/policyDefinitions/3fc4dc25-5baf-40d8-9b05-7fe74c1bc64e'
var policyResourceIdRoRootFilesystem = '/providers/Microsoft.Authorization/policyDefinitions/df49d893-a74c-421d-bc95-c663042e5b80'
var policyResourceIdEnforceResourceLimits = '/providers/Microsoft.Authorization/policyDefinitions/e345eecc-fa47-480f-9e88-67dcc122b164'
var policyResourceIdEnforceImageSource = '/providers/Microsoft.Authorization/policyDefinitions/febd0533-8e55-448f-b837-bd0e06f16469'
var policyAssignmentNameAKSLinuxRestrictive_var = guid(policyResourceIdAKSLinuxRestrictive, resourceGroup().name, clusterName)
var policyAssignmentNameEnforceHttpsIngress_var = guid(policyResourceIdEnforceHttpsIngress, resourceGroup().name, clusterName)
var policyAssignmentNameEnforceInternalLoadBalancers_var = guid(policyResourceIdEnforceInternalLoadBalancers, resourceGroup().name, clusterName)
var policyAssignmentNameRoRootFilesystem_var = guid(policyResourceIdRoRootFilesystem, resourceGroup().name, clusterName)
var policyAssignmentNameEnforceResourceLimits_var = guid(policyResourceIdEnforceResourceLimits, resourceGroup().name, clusterName)
var policyAssignmentNameEnforceImageSource_var = guid(policyResourceIdEnforceImageSource, resourceGroup().name, clusterName)

resource clusterControlPlaneIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: clusterControlPlaneIdentityName
  location: location
}

resource mi_appgateway_frontend 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'mi-appgateway-frontend'
  location: location
}

resource podmi_ingress_controller 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'podmi-ingress-controller'
  location: location
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    accessPolicies: [
      {
        tenantId: mi_appgateway_frontend.properties.tenantId
        objectId: mi_appgateway_frontend.properties.principalId
        permissions: {
          secrets: [
            'get'
          ]
          certificates: [
            'get'
          ]
          keys: []
        }
      }
      {
        tenantId: podmi_ingress_controller.properties.tenantId
        objectId: podmi_ingress_controller.properties.principalId
        permissions: {
          secrets: [
            'get'
          ]
          certificates: [
            'get'
          ]
          keys: []
        }
      }
    ]
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
  }
}

resource keyVaultName_sslcert 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: keyVault
  name: 'sslcert'
  properties: {
    value: appGatewayListenerCertificate
    recoveryLevel: 'Purgeable'
  }
}

resource keyVaultName_appgw_ingress_internal_aks_ingress_tls 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = if (!empty(aksIngressControllerCertificate)) {
  parent: keyVault
  name: 'appgw-ingress-internal-aks-ingress-tls'
  properties: {
    value: aksIngressControllerCertificate
    recoveryLevel: 'Purgeable'
  }
}

resource keyVaultName_appgw_ingress_internal_aks_ingress_key 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = if (!empty(aksIngressControllerKey)) {
  parent: keyVault
  name: 'appgw-ingress-internal-aks-ingress-key'
  properties: {
    value: aksIngressControllerKey
    recoveryLevel: 'Purgeable'
  }
}

resource keyVaultName_Microsoft_Insights_default 'Microsoft.KeyVault/vaults/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${keyVaultName}/Microsoft.Insights/default'
  properties: {
    workspaceId: resourceId(logAnalyticsResourceGroup, 'Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
    logs: [
      {
        category: 'AuditEvent'
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
  dependsOn: [
    keyVault
    laNewWorkspace
  ]
}

resource keyVaultName_Microsoft_Authorization_id_readerRole 'Microsoft.KeyVault/vaults/providers/roleAssignments@2018-09-01-preview' = {
  name: '${keyVaultName}/Microsoft.Authorization/${guid(concat(resourceGroup().id), readerRole)}'
  properties: {
    roleDefinitionId: readerRole
    principalId: podmi_ingress_controller.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    keyVault

  ]
}

resource nodepools_to_akv 'Microsoft.Network/privateEndpoints@2020-05-01' = {
  name: 'nodepools-to-akv'
  location: location
  properties: {
    subnet: {
      id: vnetHubCommonServicesSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'nodepools'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource nodepools_to_akv_default 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-05-01' = {
  parent: nodepools_to_akv
  name: 'default'
  location: location
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-akv-net'
        properties: {
          privateDnsZoneId: akvPrivateDnsZones.id
        }
      }
    ]
  }
}

resource acrPrivateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: acrPrivateDnsZonesName
  location: 'global'
  properties: {
  }
}

resource acrPrivateDnsZonesName_to_Hubvnet 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrPrivateDnsZones
  name: 'to_${HubvnetName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: hubVnetResourceId
    }
    registrationEnabled: false
  }
}

resource acrPrivateDnsZonesName_to_vnet 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrPrivateDnsZones
  name: 'to_${vnetName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: targetVnetResourceId
    }
    registrationEnabled: false
  }
}

resource akvPrivateDnsZones 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: akvPrivateDnsZonesName
  location: 'global'
  properties: {
  }
}

resource akvPrivateDnsZonesName_to_Hubvnet 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: akvPrivateDnsZones
  name: 'to_${HubvnetName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: hubVnetResourceId
    }
    registrationEnabled: false
  }
}

resource akvPrivateDnsZonesName_to_vnet 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: akvPrivateDnsZones
  name: 'to_${vnetName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: targetVnetResourceId
    }
    registrationEnabled: false
  }
}

resource asbDnsZone_resource 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: asbDnsZone
  location: 'global'
  properties: {
  }
}

resource asbDnsZone_ngsa_memory_asbDns 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  parent: asbDnsZone_resource
  name: 'ngsa-memory-${asbDnsName}'
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: '10.240.4.4'
      }
    ]
  }
}

resource asbDnsZone_to_vnet 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: asbDnsZone_resource
  name: 'to_${vnetName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: targetVnetResourceId
    }
    registrationEnabled: false
  }
}

resource asbDnsZone_to_Hubvnet 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: asbDnsZone_resource
  name: 'to_${HubvnetName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: hubVnetResourceId
    }
    registrationEnabled: false
  }
}

resource agw 'Microsoft.Network/applicationGateways@2020-05-01' = {
  name: agwName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${mi_appgateway_frontend.id}': {
      }
    }
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    sslPolicy: {
      policyType: 'Custom'
      cipherSuites: [
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
      ]
      minProtocolVersion: 'TLSv1_2'
    }
    gatewayIPConfigurations: [
      {
        name: 'apw-ip-configuration'
        properties: {
          subnet: {
            id: '${targetVnetResourceId}/subnets/snet-applicationgateway'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'apw-frontend-ip-configuration'
        properties: {
          publicIPAddress: {
            id: resourceId(subscription().subscriptionId, vNetResourceGroup, 'Microsoft.Network/publicIpAddresses', 'pip-${deploymentName}-${orgAppId}-00')
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'apw-frontend-ports'
        properties: {
          port: 443
        }
      }
      {
        name: 'apw-frontend-ports-http'
        properties: {
          port: 80
        }
      }
    ]
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
      disabledRuleGroups: [
        {
          ruleGroupName: 'REQUEST-942-APPLICATION-ATTACK-SQLI'
          rules: [
            942150
            942410
          ]
        }
      ]
    }
    enableHttp2: false
    sslCertificates: [
      {
        name: '${agwName}-ssl-certificate'
        properties: {
          keyVaultSecretId: '${keyVault.properties.vaultUri}secrets/sslcert'
        }
      }
    ]
    probes: [
      {
        name: 'probe-ngsa-memory-${asbDnsName}'
        properties: {
          protocol: 'Https'
          path: '/healthz'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'ngsa-memory-${asbDomainSuffix}'
        properties: {
          backendAddresses: [
            {
              fqdn: 'ngsa-memory-${asbDomainSuffix}'
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'ngsa-memory-${asbDnsName}-httpsettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 20
          probe: {
            id: '${agw.id}/probes/probe-ngsa-memory-${asbDnsName}'
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'listener-ngsa-memory-${asbDnsName}'
        properties: {
          frontendIPConfiguration: {
            id: '${apwResourceId}/frontendIPConfigurations/apw-frontend-ip-configuration'
          }
          frontendPort: {
            id: '${apwResourceId}/frontendPorts/apw-frontend-ports'
          }
          protocol: 'Https'
          sslCertificate: {
            id: '${apwResourceId}/sslCertificates/${agwName}-ssl-certificate'
          }
          hostName: 'ngsa-memory-${asbDomainSuffix}'
          hostNames: []
          requireServerNameIndication: true
        }
      }
      {
        name: 'http-listener-ngsa-memory-${asbDnsName}'
        properties: {
          frontendIPConfiguration: {
            id: '${apwResourceId}/frontendIPConfigurations/apw-frontend-ip-configuration'
          }
          frontendPort: {
            id: '${apwResourceId}/frontendPorts/apw-frontend-ports-http'
          }
          protocol: 'Http'
          hostName: 'ngsa-memory-${asbDomainSuffix}'
          hostNames: []
        }
      }
    ]
    redirectConfigurations: [
      {
        name: 'https-redirect-config-ngsa-memory-${asbDnsName}'
        properties: {
          redirectType: 'Permanent'
          targetListener: {
            id: '${apwResourceId}/httpListeners/listener-ngsa-memory-${asbDnsName}'
          }
          includePath: 'true'
          includeQueryString: 'true'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'ngsa-memory-${asbDnsName}-routing-rule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: '${apwResourceId}/httpListeners/listener-ngsa-memory-${asbDnsName}'
          }
          backendAddressPool: {
            id: '${apwResourceId}/backendAddressPools/ngsa-memory-${asbDomainSuffix}'
          }
          backendHttpSettings: {
            id: '${apwResourceId}/backendHttpSettingsCollection/ngsa-memory-${asbDnsName}-httpsettings'
          }
        }
      }
      {
        name: 'https-redirect-ngsa-memory-${asbDnsName}-routing-rule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: '${apwResourceId}/httpListeners/http-listener-ngsa-memory-${asbDnsName}'
          }
          redirectConfiguration: {
            id: '${apwResourceId}/redirectConfigurations/https-redirect-config-ngsa-memory-${asbDnsName}'
          }
        }
      }
    ]
  }
}

resource agwName_Microsoft_Insights_default 'Microsoft.Network/applicationGateways/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${agwName}//Microsoft.Insights/default'
  properties: {
    workspaceId: resourceId(logAnalyticsResourceGroup, 'Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
      }
    ]
  }
  dependsOn: [
    agw
    laNewWorkspace
  ]
}

module EnsureClusterIdentityHasRbacToSelfManagedResources './nested_EnsureClusterIdentityHasRbacToSelfManagedResources.bicep' = {
  name: 'EnsureClusterIdentityHasRbacToSelfManagedResources'
  scope: resourceGroup(vNetResourceGroup)
  params: {
    resourceId_Microsoft_ManagedIdentity_userAssignedIdentities_variables_clusterControlPlaneIdentityName: clusterControlPlaneIdentity.properties
    variables_vnetNodePoolSubnetResourceId: vnetNodePoolSubnetResourceId
    variables_networkContributorRole: networkContributorRole
    variables_clusterControlPlaneIdentityName: clusterControlPlaneIdentityName
    variables_vnetName: vnetName
    variables_vnetIngressServicesSubnetResourceId: vnetIngressServicesSubnetResourceId
  }
}

module EnsureClusterUserAssignedHasRbacToManageVMSS './nested_EnsureClusterUserAssignedHasRbacToManageVMSS.bicep' = {
  name: 'EnsureClusterUserAssignedHasRbacToManageVMSS'
  scope: resourceGroup(nodeResourceGroupName)
  params: {
    resourceId_Microsoft_ContainerService_managedClusters_variables_clusterName: reference(cluster.id, '2020-03-01')
    variables_virtualMachineContributorRole: virtualMachineContributorRole
    location: location
  }
}

resource laNewWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = if (isNewLogAnalytics) {
  name: laNewWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource laNewWorkspaceName_AllPrometheus 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = if (isNewLogAnalytics) {
  parent: laNewWorkspace
  name: 'AllPrometheus'
  properties: {
    eTag: '*'
    category: 'Prometheus'
    displayName: 'All collected Prometheus information'
    query: 'InsightsMetrics | where Namespace == "prometheus"'
    version: 1
  }
}

resource laNewWorkspaceName_ForbiddenReponsesOnIngress 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = if (isNewLogAnalytics) {
  parent: laNewWorkspace
  name: 'ForbiddenReponsesOnIngress'
  properties: {
    eTag: '*'
    category: 'Prometheus'
    displayName: 'Increase number of forbidden response on the Ingress Controller'
    query: 'let value = toscalar(InsightsMetrics | where Namespace == "prometheus" and Name == "traefik_entrypoint_requests_total" | where parse_json(Tags).code == 403 | summarize Value = avg(Val) by bin(TimeGenerated, 5m) | summarize min = min(Value)); InsightsMetrics | where Namespace == "prometheus" and Name == "traefik_entrypoint_requests_total" | where parse_json(Tags).code == 403 | summarize AggregatedValue = avg(Val)-value by bin(TimeGenerated, 5m) | order by TimeGenerated | render barchart'
    version: 1
  }
}

resource laNewWorkspaceName_NodeRebootRequested 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = if (isNewLogAnalytics) {
  parent: laNewWorkspace
  name: 'NodeRebootRequested'
  properties: {
    eTag: '*'
    category: 'Prometheus'
    displayName: 'Nodes reboot required by kured'
    query: 'InsightsMetrics | where Namespace == "prometheus" and Name == "kured_reboot_required" | where Val > 0'
    version: 1
  }
}

resource PodFailedScheduledQuery_cluster 'Microsoft.Insights/scheduledQueryRules@2018-04-16' = if (isNewLogAnalytics) {
  name: 'PodFailedScheduledQuery-${clusterName}'
  location: location
  properties: {
    description: 'Alert on pod Failed phase.'
    enabled: 'true'
    source: {
      query: '//https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-alerts \r\n let endDateTime = now(); let startDateTime = ago(1h); let trendBinSize = 1m; let clusterName = "${clusterName}"; KubePodInventory | where TimeGenerated < endDateTime | where TimeGenerated >= startDateTime | where ClusterName == clusterName | distinct ClusterName, TimeGenerated | summarize ClusterSnapshotCount = count() by bin(TimeGenerated, trendBinSize), ClusterName | join hint.strategy=broadcast ( KubePodInventory | where TimeGenerated < endDateTime | where TimeGenerated >= startDateTime | distinct ClusterName, Computer, PodUid, TimeGenerated, PodStatus | summarize TotalCount = count(), PendingCount = sumif(1, PodStatus =~ "Pending"), RunningCount = sumif(1, PodStatus =~ "Running"), SucceededCount = sumif(1, PodStatus =~ "Succeeded"), FailedCount = sumif(1, PodStatus =~ "Failed") by ClusterName, bin(TimeGenerated, trendBinSize) ) on ClusterName, TimeGenerated | extend UnknownCount = TotalCount - PendingCount - RunningCount - SucceededCount - FailedCount | project TimeGenerated, TotalCount = todouble(TotalCount) / ClusterSnapshotCount, PendingCount = todouble(PendingCount) / ClusterSnapshotCount, RunningCount = todouble(RunningCount) / ClusterSnapshotCount, SucceededCount = todouble(SucceededCount) / ClusterSnapshotCount, FailedCount = todouble(FailedCount) / ClusterSnapshotCount, UnknownCount = todouble(UnknownCount) / ClusterSnapshotCount| summarize AggregatedValue = avg(FailedCount) by bin(TimeGenerated, trendBinSize)'
      dataSourceId: resourceId(logAnalyticsResourceGroup, 'Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
      queryType: 'ResultCount'
    }
    schedule: {
      frequencyInMinutes: 5
      timeWindowInMinutes: 10
    }
    action: {
      'odata.type': 'Microsoft.WindowsAzure.Management.Monitoring.Alerts.Models.Microsoft.AppInsights.Nexus.DataContracts.Resources.ScheduledQueryRules.AlertingAction'
      severity: 3
      trigger: {
        thresholdOperator: 'GreaterThan'
        threshold: 3
        metricTrigger: {
          thresholdOperator: 'GreaterThan'
          threshold: 2
          metricTriggerType: 'Consecutive'
        }
      }
    }
  }
  dependsOn: [
    containerInsightsSolution
    cluster
  ]
}

resource AllAzureAdvisorAlert 'microsoft.insights/activityLogAlerts@2017-04-01' = {
  name: 'AllAzureAdvisorAlert'
  location: 'Global'
  properties: {
    scopes: [
      resourceGroup().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Recommendation'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Advisor/recommendations/available/action'
        }
      ]
    }
    actions: {
      actionGroups: []
    }
    enabled: true
    description: 'All azure advisor alerts'
  }
}

resource containerInsightsSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = if (isNewLogAnalytics) {
  name: containerInsightsSolutionName
  location: location
  properties: {
    workspaceResourceId: resourceId(logAnalyticsResourceGroup, 'Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
  }
  plan: {
    name: containerInsightsSolutionName
    product: 'OMSGallery/ContainerInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
  dependsOn: [
    laNewWorkspace
  ]
}

resource KeyVaultAnalytics_logAnalyticsWorkspace 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = if (isNewLogAnalytics) {
  name: 'KeyVaultAnalytics(${logAnalyticsWorkspaceName})'
  location: location
  properties: {
    workspaceResourceId: resourceId(logAnalyticsResourceGroup, 'Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
  }
  plan: {
    name: 'KeyVaultAnalytics(${logAnalyticsWorkspaceName})'
    product: 'OMSGallery/KeyVaultAnalytics'
    promotionCode: ''
    publisher: 'Microsoft'
  }
  dependsOn: [
    laNewWorkspace
  ]
}

resource defaultAcr 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' = {
  name: defaultAcrName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Deny'
      virtualNetworkRules: []
      ipRules: []
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 15
        status: 'enabled'
      }
    }
    publicNetworkAccess: 'Disabled'
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: true
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
  }
}

resource defaultAcrName_Microsoft_Authorization_Microsoft_ContainerService_managedClusters_clusterName_acrPullRole 'Microsoft.ContainerRegistry/registries/providers/roleAssignments@2020-04-01-preview' = {
  name: '${defaultAcrName}/Microsoft.Authorization/${guid(cluster.id, acrPullRole)}'
  properties: {
    roleDefinitionId: acrPullRole
    principalId: reference(cluster.id, '2020-12-01').identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    defaultAcr

  ]
}

resource defaultAcrName_geoRedundancyLocation 'Microsoft.ContainerRegistry/registries/replications@2019-05-01' = {
  parent: defaultAcr
  name: '${geoRedundancyLocation}'
  location: geoRedundancyLocation
  properties: {
  }
}

resource defaultAcrName_Microsoft_Insights_default 'Microsoft.ContainerRegistry/registries/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${defaultAcrName}/Microsoft.Insights/default'
  properties: {
    workspaceId: resourceId(logAnalyticsResourceGroup, 'Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
    metrics: [
      {
        timeGrain: 'PT1M'
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        category: 'ContainerRegistryRepositoryEvents'
        enabled: true
      }
      {
        category: 'ContainerRegistryLoginEvents'
        enabled: true
      }
    ]
  }
  dependsOn: [
    defaultAcr
    laNewWorkspace
  ]
}

resource nodepools_to_acr 'Microsoft.Network/privateEndpoints@2020-05-01' = {
  name: 'nodepools-to-acr'
  location: location
  properties: {
    subnet: {
      id: vnetHubCommonServicesSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'nodepools'
        properties: {
          privateLinkServiceId: defaultAcr.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
  dependsOn: [
    defaultAcrName_geoRedundancyLocation
  ]
}

resource nodepools_to_acr_default 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-05-01' = {
  parent: nodepools_to_acr
  name: 'default'
  location: location
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azurecr-io'
        properties: {
          privateDnsZoneId: acrPrivateDnsZones.id
        }
      }
    ]
  }
}

resource cluster 'Microsoft.ContainerService/managedClusters@2022-02-02-preview' = {
  name: clusterName
  location: location
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: uniqueString(subscription().subscriptionId, resourceGroup().id, clusterName)
    agentPoolProfiles: [
      {
        name: 'npsystem'
        count: 3
        vmSize: 'Standard_A4_v2'
        osDiskSizeGB: 80
        osDiskType: 'Managed'
        osType: 'Linux'
        minCount: 3
        maxCount: 4
        vnetSubnetID: vnetNodePoolSubnetResourceId
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: kubernetesVersion
        enableNodePublicIP: false
        maxPods: 100
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
      {
        name: 'npuser01'
        count: 2
        vmSize: 'Standard_A4_v2'
        osDiskSizeGB: 120
        osDiskType: 'Managed'
        osType: 'Linux'
        minCount: 2
        maxCount: 5
        vnetSubnetID: vnetNodePoolSubnetResourceId
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: kubernetesVersion
        enableNodePublicIP: false
        maxPods: 100
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      httpApplicationRouting: {
        enabled: false
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceId: resourceId(logAnalyticsResourceGroup, 'Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
        }
      }
      aciConnectorLinux: {
        enabled: false
      }
      azurepolicy: {
        enabled: true
        config: {
          version: 'v2'
        }
      }
    }
    nodeResourceGroup: nodeResourceGroupName
    enableRBAC: true
    enablePodSecurityPolicy: false
    maxAgentPools: 2
    networkProfile: {
      networkPlugin: 'none'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: false
      adminGroupObjectIDs: [
        clusterAdminAadGroupObjectId
      ]
      tenantID: k8sControlPlaneAuthorizationTenantId
    }
    autoScalerProfile: {
      'balance-similar-node-groups': 'false'
      expander: 'random'
      'max-empty-bulk-delete': '10'
      'max-graceful-termination-sec': '600'
      'max-node-provision-time': '15m'
      'max-total-unready-percentage': '45'
      'new-pod-scale-up-delay': '0s'
      'ok-total-unready-count': '3'
      'scale-down-delay-after-add': '10m'
      'scale-down-delay-after-delete': '20s'
      'scale-down-delay-after-failure': '3m'
      'scale-down-unneeded-time': '10m'
      'scale-down-unready-time': '20m'
      'scale-down-utilization-threshold': '0.5'
      'scan-interval': '10s'
      'skip-nodes-with-local-storage': 'true'
      'skip-nodes-with-system-pods': 'true'
    }
    apiServerAccessProfile: {
      authorizedIPRanges: clusterAuthorizedIPRanges
      enablePrivateCluster: false
    }
    podIdentityProfile: {
      enabled: false
      userAssignedIdentities: []
      userAssignedIdentityExceptions: []
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${clusterControlPlaneIdentity.id}': {
      }
    }
  }
  dependsOn: [
    containerInsightsSolution
    resourceId(vNetResourceGroup, 'Microsoft.Resources/deployments', 'EnsureClusterIdentityHasRbacToSelfManagedResources')

    policyAssignmentNameAKSLinuxRestrictive
    policyAssignmentNameEnforceHttpsIngress
    policyAssignmentNameEnforceImageSource
    policyAssignmentNameEnforceInternalLoadBalancers
    policyAssignmentNameEnforceResourceLimits
    policyAssignmentNameRoRootFilesystem
  ]
}

resource clusterName_Microsoft_Authorization_Microsoft_ContainerService_managedClusters_clusterName_omsagent_monitoringMetricsPublisherRole 'Microsoft.ContainerService/managedClusters/providers/roleAssignments@2020-04-01-preview' = {
  name: '${clusterName}/Microsoft.Authorization/${guid(cluster.id, 'omsagent', monitoringMetricsPublisherRole)}'
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRole
    principalId: reference(cluster.id, '2020-12-01').addonProfiles.omsagent.identity.objectId
    principalType: 'ServicePrincipal'
  }
}

resource clusterName_Microsoft_Insights_default 'Microsoft.ContainerService/managedClusters/providers/diagnosticSettings@2017-05-01-preview' = {
  name: '${clusterName}/Microsoft.Insights/default'
  properties: {
    workspaceId: resourceId(logAnalyticsResourceGroup, 'Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
    logs: [
      {
        category: 'cluster-autoscaler'
        enabled: true
      }
      {
        category: 'kube-controller-manager'
        enabled: true
      }
      {
        category: 'kube-audit-admin'
        enabled: true
      }
      {
        category: 'guard'
        enabled: true
      }
    ]
  }
  dependsOn: [
    cluster
    laNewWorkspace
  ]
}

resource Node_CPU_utilization_high_for_clusterName_CI_1 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  location: 'global'
  name: 'Node CPU utilization high for ${clusterName} CI-1'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'host'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'cpuUsagePercentage'
          metricNamespace: 'Insights.Container/nodes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: '80'
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'Node CPU utilization across the cluster.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      cluster.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [

    containerInsightsSolution
  ]
}

resource Node_working_set_memory_utilization_high_for_clusterName_CI_2 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  location: 'global'
  name: 'Node working set memory utilization high for ${clusterName} CI-2'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'host'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'memoryWorkingSetPercentage'
          metricNamespace: 'Insights.Container/nodes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: '80'
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'Node working set memory utilization across the cluster.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      cluster.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [

    containerInsightsSolution
  ]
}

resource Jobs_completed_more_than_6_hours_ago_for_clusterName_CI_11 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  location: 'global'
  name: 'Jobs completed more than 6 hours ago for ${clusterName} CI-11'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'completedJobsCount'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: '0'
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors completed jobs (more than 6 hours ago).'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      cluster.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT1M'
  }
  dependsOn: [

    containerInsightsSolution
  ]
}

resource Container_CPU_usage_high_for_clusterName_CI_9 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  location: 'global'
  name: 'Container CPU usage high for ${clusterName} CI-9'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'cpuExceededPercentage'
          metricNamespace: 'Insights.Container/containers'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: '90'
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors container CPU utilization.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      cluster.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [

    containerInsightsSolution
  ]
}

resource Container_working_set_memory_usage_high_for_clusterName_CI_10 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  location: 'global'
  name: 'Container working set memory usage high for ${clusterName} CI-10'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'memoryWorkingSetExceededPercentage'
          metricNamespace: 'Insights.Container/containers'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: '90'
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors container working set memory utilization.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      cluster.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [

    containerInsightsSolution
  ]
}

resource Pods_in_failed_state_for_clusterName_CI_4 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  location: 'global'
  name: 'Pods in failed state for ${clusterName} CI-4'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'phase'
              operator: 'Include'
              values: [
                'Failed'
              ]
            }
          ]
          metricName: 'podCount'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: '0'
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'Pod status monitoring.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      cluster.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [

    containerInsightsSolution
  ]
}

resource Disk_usage_high_for_clusterName_CI_5 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  location: 'global'
  name: 'Disk usage high for ${clusterName} CI-5'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'host'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'device'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'DiskUsedPercentage'
          metricNamespace: 'Insights.Container/nodes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: '80'
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors disk usage for all nodes and storage devices.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      cluster.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [

    containerInsightsSolution
  ]
}

resource Nodes_in_not_ready_status_for_clusterName_CI_3 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  location: 'global'
  name: 'Nodes in not ready status for ${clusterName} CI-3'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'status'
              operator: 'Include'
              values: [
                'NotReady'
              ]
            }
          ]
          metricName: 'nodesCount'
          metricNamespace: 'Insights.Container/nodes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: '0'
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'Node status monitoring.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      cluster.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [

    containerInsightsSolution
  ]
}

resource Containers_getting_OOM_killed_for_clusterName_CI_6 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  location: 'global'
  name: 'Containers getting OOM killed for ${clusterName} CI-6'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'oomKilledContainerCount'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: '0'
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors number of containers killed due to out of memory (OOM) error.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      cluster.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT1M'
  }
  dependsOn: [

    containerInsightsSolution
  ]
}

resource Persistent_volume_usage_high_for_clusterName_CI_18 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  location: 'global'
  name: 'Persistent volume usage high for ${clusterName} CI-18'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'podName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetesNamespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'pvUsageExceededPercentage'
          metricNamespace: 'Insights.Container/persistentvolumes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: '80'
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors persistent volume utilization.'
    enabled: false
    evaluationFrequency: 'PT1M'
    scopes: [
      cluster.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [

    containerInsightsSolution
  ]
}

resource Pods_not_in_ready_state_for_clusterName_CI_8 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  location: 'global'
  name: 'Pods not in ready state for ${clusterName} CI-8'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'PodReadyPercentage'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'LessThan'
          threshold: '80'
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors for excessive pods not in the ready state.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      cluster.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [

    containerInsightsSolution
  ]
}

resource Restarting_container_count_for_clusterName_CI_7 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  location: 'global'
  name: 'Restarting container count for ${clusterName} CI-7'
  properties: {
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'restartingContainerCount'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: '0'
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors number of containers restarting across the cluster.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      cluster.id
    ]
    severity: 3
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    windowSize: 'PT1M'
  }
  dependsOn: [

    containerInsightsSolution
  ]
}

resource podmi_ingress_controller_Microsoft_Authorization_id_managedIdentityOperatorRole_cluster 'Microsoft.ManagedIdentity/userAssignedIdentities/providers/roleAssignments@2018-09-01-preview' = {
  name: 'podmi-ingress-controller/Microsoft.Authorization/${guid(concat(resourceGroup().id), managedIdentityOperatorRole, clusterName)}'
  properties: {
    roleDefinitionId: managedIdentityOperatorRole
    principalId: reference(cluster.id, '2020-11-01').identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

resource policyAssignmentNameAKSLinuxRestrictive 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: policyAssignmentNameAKSLinuxRestrictive_var
  properties: {
    displayName: concat(reference(policyResourceIdAKSLinuxRestrictive, '2020-09-01').displayName)
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdAKSLinuxRestrictive
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'cluster-baseline-settings'
          'flux-cd'
          'ngsa'
          'tiny'
        ]
      }
      effect: {
        value: 'audit'
      }
    }
  }
}

resource policyAssignmentNameEnforceHttpsIngress 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: policyAssignmentNameEnforceHttpsIngress_var
  properties: {
    displayName: concat(reference(policyResourceIdEnforceHttpsIngress, '2020-09-01').displayName)
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceHttpsIngress
    parameters: {
      excludedNamespaces: {
        value: []
      }
      effect: {
        value: 'deny'
      }
    }
  }
}

resource policyAssignmentNameEnforceInternalLoadBalancers 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: policyAssignmentNameEnforceInternalLoadBalancers_var
  properties: {
    displayName: concat(reference(policyResourceIdEnforceInternalLoadBalancers, '2020-09-01').displayName)
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceInternalLoadBalancers
    parameters: {
      excludedNamespaces: {
        value: []
      }
      effect: {
        value: 'deny'
      }
    }
  }
}

resource policyAssignmentNameRoRootFilesystem 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: policyAssignmentNameRoRootFilesystem_var
  properties: {
    displayName: concat(reference(policyResourceIdRoRootFilesystem, '2020-09-01').displayName)
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdRoRootFilesystem
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      effect: {
        value: 'audit'
      }
    }
  }
}

resource policyAssignmentNameEnforceResourceLimits 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: policyAssignmentNameEnforceResourceLimits_var
  properties: {
    displayName: concat(reference(policyResourceIdEnforceResourceLimits, '2020-09-01').displayName)
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceResourceLimits
    parameters: {
      cpuLimit: {
        value: '1000m'
      }
      memoryLimit: {
        value: '512Mi'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'cluster-baseline-settings'
          'flux-cd'
          'ngsa'
          'tiny'
        ]
      }
      effect: {
        value: 'deny'
      }
    }
  }
}

resource policyAssignmentNameEnforceImageSource 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: policyAssignmentNameEnforceImageSource_var
  properties: {
    displayName: concat(reference(policyResourceIdEnforceImageSource, '2020-09-01').displayName)
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceImageSource
    parameters: {
      allowedContainerImagesRegex: {
        value: '${defaultAcrName}.azurecr.io/.+$|ghcr.io/retaildevcrews/.+$|mcr.microsoft.com/.+$|docker.io/fluxcd/flux.+$|docker.io/weaveworks/kured.+$|docker.io/retaildevcrew/.+$|docker.io/library/.+$'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'flux-cd'
          'ingress'
        ]
      }
      effect: {
        value: 'deny'
      }
    }
  }
}

output aksClusterName string = clusterName
output agwName string = agwName
output aksIngressControllerPodManagedIdentityResourceId string = podmi_ingress_controller.id
output aksIngressControllerPodManagedIdentityClientId string = reference(podmi_ingress_controller.id, '2018-11-30').clientId
output keyVaultName string = keyVaultName
output logAnalyticsName string = logAnalyticsWorkspaceName
output containerRegistryName string = defaultAcrName
output vnetNodePoolSubnetResourceId string = vnetNodePoolSubnetResourceId