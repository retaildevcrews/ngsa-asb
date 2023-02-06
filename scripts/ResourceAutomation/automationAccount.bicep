targetScope='resourceGroup'



@description('URL of the shutdown script')
param resourceStartStopRunbookURL string= 'https://raw.githubusercontent.com/retaildevcrews/ngsa-asb/pragmatical/azureautomation/scripts/ResourceAutomation/runbooks/resource_start_stop.ps1'

@description('Name of location')
param location string = resourceGroup().location

@description('Name of automation account')
param AA_Name string 

@description('Name of user assigned managed identity')
param MI_Name string 

@description('Role definition ID')
param RA_role_def_id string = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

@description('Role definition ID')
param RA_module string = 'ra-module'

@description('Time Zone for Schedules')
param scheduleTimezone string = 'America/Chicago'

@description('Start of day datetime for schedule')
param scheduleStartOfDayTime string = '${dateTimeAdd(utcNow(), 'P1D', 'yyyy-MM-dd')}T09:00:00-06:00'
output startOfDayOutput string = scheduleStartOfDayTime
@description('End of day datetime for schedule')
param scheduleEndOfDayTime string = '${dateTimeAdd(utcNow(), 'P1D', 'yyyy-MM-dd')}T17:00:00-06:00'
output endOfDayOutput string = scheduleEndOfDayTime

param resourcesToAutomate array= [
  {
    resourceGroup: 'rg-wcnp-pre'
    clusterName: 'aks-ri3aov7twb4uy-eastus'
    gatewayName: 'apw-aks-ri3aov7twb4uy-eastus'
  }
  {
    resourceGroup: 'rg-wcnp-pre'
    clusterName: 'aks-ri3aov7twb4uy-northcentralus'
    gatewayName: 'apw-aks-ri3aov7twb4uy-northcentralus'
  }
  {
    resourceGroup: 'rg-wcnp-pre'
    clusterName: 'aks-ri3aov7twb4uy-westus3'
    gatewayName: 'apw-aks-ri3aov7twb4uy-westus3'
  }
  {
    resourceGroup: 'rg-wcnp-dev'
    clusterName: 'aks-jxdthrti3j3qu-eastus'
    gatewayName: 'apw-aks-jxdthrti3j3qu-eastus'
  }
  {
    resourceGroup: 'rg-wcnp-dev'
    clusterName: 'aks-jxdthrti3j3qu-westus3'
    gatewayName: 'apw-aks-jxdthrti3j3qu-westus3'
  }
]

resource automationMI 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: MI_Name
  location: location
}

resource automationAccount 'Microsoft.Automation/automationAccounts@2022-08-08' = {
  name: AA_Name
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities:{'${automationMI.id}': {}}
  }
  properties: {
    disableLocalAuth: true
    publicNetworkAccess: false 
    sku: {
      name: 'Basic'
    }
    encryption:{
      keySource: 'Microsoft.Automation'
      identity: {}
    }
  }
}

module roleAssignment 'roleAssignment.bicep' = {
   name: RA_module
   scope: subscription()
   params: {
    roleAssignmentName:guid(subscription().id,automationMI.properties.principalId,RA_role_def_id)
    roleDefId: resourceId('Microsoft.Authorization/roleDefinitions', RA_role_def_id)
    userPrincipalId:automationMI.properties.principalId
   }
}

resource weekdaysStartOfDaySchedule 'Microsoft.Automation/automationAccounts/schedules@2022-08-08' = {
  name: 'weekdays-start-of-day'
  parent: automationAccount
  properties: {
    advancedSchedule: {
      weekDays: [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday' ]
    }
    description: 'Schedule that runs every weekday at specified time'
    interval: 1
    frequency: 'Week'
    startTime: scheduleStartOfDayTime 
    expiryTime: '9999-12-31T17:59:00-06:00'
    timeZone: scheduleTimezone
  }
}

resource weekdaysEndOfDaySchedule 'Microsoft.Automation/automationAccounts/schedules@2022-08-08' = {
  name: 'weekdays-end-of-day'
  parent: automationAccount
  properties: {
    advancedSchedule: {
      weekDays: [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday' ]
    }
    description: 'Schedule that runs every weekday at specified time'
    interval: 1
    frequency: 'Week'
    startTime: scheduleEndOfDayTime
    expiryTime: '9999-12-31T17:59:00-06:00'
    timeZone: scheduleTimezone
  }
}

resource resourceBringupRunbooks 'Microsoft.Automation/automationAccounts/runbooks@2022-08-08' = [for resourceToAutomate in resourcesToAutomate: {
  name: 'runbook-${resourceToAutomate.clusterName}-bringup'
  location: location
  parent: automationAccount
  properties: {
    description: 'Runbook to bring up ${resourceToAutomate.clusterName} and ${resourceToAutomate.gatewayName} at the beginning of the day'
    logProgress: true
    logVerbose: true
    publishContentLink: {
      uri: resourceStartStopRunbookURL
    }
    runbookType: 'PowerShell'
  }
}]

resource resourceBringupRunbookSchedules 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = [for resourceToAutomate in resourcesToAutomate: {
  name: guid('resource-bringup-schedule',resourceToAutomate.clusterName,AA_Name,'bringup')
  parent: automationAccount
  properties: {
    parameters: {
      tenantId: tenant().tenantId
      subscriptionName: subscription().displayName
      automationAccountResourceGroup: resourceGroup().name
      automationAccountName: AA_Name
      managedIdentityClientId: automationMI.properties.clientId
      resourceGroup: resourceToAutomate.resourceGroup
      clusterName: resourceToAutomate.clusterName
      gatewayName: resourceToAutomate.gatewayName
      operation: 'start'
    }
    runbook: {
      name: 'runbook-${resourceToAutomate.clusterName}-bringup'
    }
    schedule: {
      name: 'weekdays-start-of-day'
    }
  }
  dependsOn:[resourceBringupRunbooks,weekdaysStartOfDaySchedule]
}]

resource resourceShutdownRunbooks 'Microsoft.Automation/automationAccounts/runbooks@2022-08-08' = [for resourceToAutomate in resourcesToAutomate: {
  name: 'runbook-${resourceToAutomate.clusterName}-shutdown'
  location: location
  parent: automationAccount
  properties: {
    description: 'Runbook to shut down ${resourceToAutomate.clusterName} and ${resourceToAutomate.gatewayName} at the end of the day'
    logProgress: true
    logVerbose: true
    publishContentLink: {
      uri: resourceStartStopRunbookURL
    }
    runbookType: 'PowerShell'
  }
}]

resource resourceShutdownRunbookSchedules 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = [for resourceToAutomate in resourcesToAutomate: {
  name: guid('resource-shutdown-schedule',resourceToAutomate.clusterName,AA_Name,'shutdown')
  parent: automationAccount
  properties: {
    parameters: {
      tenantId: tenant().tenantId
      subscriptionName: subscription().displayName
      automationAccountResourceGroup: resourceGroup().name
      automationAccountName: AA_Name
      managedIdentityClientId: automationMI.properties.clientId
      resourceGroup: resourceToAutomate.resourceGroup
      clusterName: resourceToAutomate.clusterName
      gatewayName: resourceToAutomate.gatewayName
      operation: 'stop'
    }
    runbook: {
      name: 'runbook-${resourceToAutomate.clusterName}-shutdown'
    }
    schedule: {
      name: 'weekdays-end-of-day'
    }
  }
  dependsOn:[resourceShutdownRunbooks,weekdaysEndOfDaySchedule]
}]
