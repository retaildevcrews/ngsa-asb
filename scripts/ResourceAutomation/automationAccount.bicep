targetScope='resourceGroup'

@description('Log analytics workspace id')
param logAnalyticsWorkspaceId string

@description('URL of the bringup/shutdown script')
param clusterGwStartStopRunbookURL string

@description('Name of location')
param location string = resourceGroup().location

@description('Name of automation account')
param AA_Name string 

@description('Name of user assigned managed identity')
param MI_Name string 

@description('Role definition ID')
param RA_role_def_id string = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

@description('Role assignment module name')
param RA_module string = 'ra-module'

@description('Time Zone for Schedules')
param scheduleTimezone string

@description('Start of day datetime for schedule')
param scheduleStartOfDayTime string = '${dateTimeAdd(utcNow(), 'P1D', 'yyyy-MM-dd')}T09:00:00-06:00'

@description('End of day datetime for schedule')
param scheduleEndOfDayTime string = '${dateTimeAdd(utcNow(), 'P1D', 'yyyy-MM-dd')}T20:00:00-06:00'

@description('Log Verbose Messages in Runbooks')
param logVerbose bool = false

@description('Log Progress Messages in Runbooks')
param logProgress bool = false

@description('Array of objects that define what needs to be automated  - gateway, and cluster (assumes they are in the same resource group)')
param resourcesToAutomate array

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


resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${automationAccount.name}-diagnostic-settings'
  scope: automationAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'JobLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 0
        }
      }
      {
        category: 'JobStreams'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 0
        }
      }
    ]
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
    logProgress: logProgress
    logVerbose: logVerbose
    publishContentLink: {
      uri: clusterGwStartStopRunbookURL
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
    logProgress: logProgress
    logVerbose: logVerbose
    publishContentLink: {
      uri: clusterGwStartStopRunbookURL
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
