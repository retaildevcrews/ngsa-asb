targetScope = 'subscription'

@description('Unique portion of automation resource names used for naming resource group, automation account, and managed identity')
param automationSuffix string='automation-test1'

@description('Name of resource group')
param RG_Name string = 'rg-${automationSuffix}'

@description('Role definition ID')
param RA_role_def_id string = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

@description('Name of automation account')
param AA_Name string = 'aa-${automationSuffix}'

@description('Name of user assigned managed identity')
param MI_Name string = 'mi-${automationSuffix}'

@description('Name of location')
@allowed([ 'northcentralus', 'eastus', 'westus3' ])
param location string = 'eastus'

@description('Log analytics workspace id')
param logAnalyticsWorkspaceId string

@description('URL of the bringup/shutdown script')
param clusterGwStartStopRunbookURL string

@description('Firewall URL of the bringup/shutdown script')
param firewallStartStopRunbookURL string

@description('Start of day datetime for schedule')
param scheduleStartOfDayTime string='09:00:00'

@description('End of day datetime for schedule')
param scheduleEndOfDayTime string='20:00:00' 

@description('Time Zone for Schedules')
param scheduleTimezone string

@description('Log Verbose Messages in Runbooks')
param logVerbose bool = false

@description('Log Progress Messages in Runbooks')
param logProgress bool = false

@description('Array of objects that define what needs to be automated  - gateway, and cluster (assumes they are in the same resource group)')
param resourcesToAutomate array

@description('Array of Firewall objects that need to be automated')
param firewallsToAutomate array


resource automationRG 'Microsoft.Resources/resourceGroups@2021-04-01' = { name: RG_Name, location: location }

module automationAccountModule 'automationAccount.bicep' = {
  name: MI_Name
  scope: resourceGroup(RG_Name)
  params:{
    location:location
    AA_Name:AA_Name
    MI_Name:MI_Name
    logAnalyticsWorkspaceId:logAnalyticsWorkspaceId
    clusterGwStartStopRunbookURL:clusterGwStartStopRunbookURL
    firewallStartStopRunbookURL: firewallStartStopRunbookURL
    scheduleStartOfDayTime:scheduleStartOfDayTime
    scheduleEndOfDayTime:scheduleEndOfDayTime
    scheduleTimezone:scheduleTimezone
    logProgress:logProgress
    logVerbose:logVerbose
    resourcesToAutomate:resourcesToAutomate
    firewallsToAutomate:firewallsToAutomate
  }
  dependsOn:[automationRG]
}

resource AA_RoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id,MI_Name)
  scope: subscription()
  properties: {
    principalId: automationAccountModule.outputs.aaMIPrincipalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', RA_role_def_id)
    principalType: 'ServicePrincipal'
  }
}
