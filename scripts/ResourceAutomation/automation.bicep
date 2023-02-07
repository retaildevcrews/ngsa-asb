targetScope = 'subscription'

@description('Unique portion of automation resource names used for naming resource group, automation account, and managed identity')
param AA_accountSuffix string='automation'

@description('Name of resource group')
param RG_Name string = 'rg-${AA_accountSuffix}'

@description('Name of automation account')
param AA_Name string = 'aa-${AA_accountSuffix}'

@description('Name of user assigned managed identity')
param MI_Name string = 'mi-${AA_accountSuffix}'

@description('Name of location')
@allowed([ 'centralus', 'eastus', 'westus3' ])
param location string = 'eastus'

@description('Log analytics workspace id')
param logAnalyticsWorkspaceId string

@description('URL of the bringup/shutdown script')
param resourceStartStopRunbookURL string


@description('Time Zone for Schedules')
param scheduleTimezone string

@description('Log Verbose Messages in Runbooks')
param logVerbose bool = false

@description('Log Progress Messages in Runbooks')
param logProgress bool = false

resource automationRG 'Microsoft.Resources/resourceGroups@2021-04-01' = { name: RG_Name, location: location }

module automationAccountModule 'automationAccount.bicep' = {
  name: MI_Name
  scope: resourceGroup(RG_Name)
  params:{
    location:location
    AA_Name:AA_Name
    MI_Name:MI_Name
    logAnalyticsWorkspaceId:logAnalyticsWorkspaceId
    resourceStartStopRunbookURL:resourceStartStopRunbookURL
    scheduleTimezone:scheduleTimezone
    logProgress:logProgress
    logVerbose:logVerbose
  }
  dependsOn:[automationRG]
}




