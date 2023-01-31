targetScope='resourceGroup'

@description('URL of the shutdown script')
param resourceShutdownRunbookURL string= 'https://raw.githubusercontent.com/retaildevcrews/ngsa-asb/main/scripts/Aks-Cluster-Automation/Aks-Cluster-Automation-Runbook.ps1'

@description('URL of the bringup script')
param resourceBringupRunbookURL string= 'https://raw.githubusercontent.com/retaildevcrews/ngsa-asb/main/scripts/Aks-Cluster-Automation/Aks-Cluster-Automation-Runbook.ps1'

@description('Name of location')
param location string = resourceGroup().location

@description('Name of user assigned managed identity')
param AA_Name string 

@description('Name of user assigned managed identity')
param MI_Name string 

@description('Role definition ID')
param RA_role_def_id string = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

@description('Role definition ID')
param RA_module string = 'ra-module'

@description('Time Zone for Schedules')
param scheduleTimezone string = 'America/Chicago'

@description('Time Zone for Schedules')
param scheduleStartOfDayTime string = '2023-02-01T09:00:00-06:00'

@description('Time Zone for Schedules')
param scheduleEndOfDayTime string = '2023-02-01T17:00:00-06:00'

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

resource resourceShutdownRunbook 'Microsoft.Automation/automationAccounts/runbooks@2022-08-08' = {
  name: 'resource-shutdown'
  location: location
  parent: automationAccount
  properties: {
    description: 'Runbook to shut down resources at the end of the day'
    logProgress: true
    logVerbose: true
    publishContentLink: {
      uri: resourceShutdownRunbookURL
    }
    runbookType: 'PowerShell'
  }
}

resource resourceBringupRunbook 'Microsoft.Automation/automationAccounts/runbooks@2022-08-08' = {
  name: 'resource-bringup'
  location: location
  parent: automationAccount
  properties: {
    description: 'Runbook to shut down resources at the end of the day'
    logProgress: true
    logVerbose: true
    publishContentLink: {
      uri: resourceBringupRunbookURL
    }
    runbookType: 'PowerShell'
  }
}

resource resourceShutdownRunbookSchedule 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = {
  name: guid('resource-shutdown-schedule')
  parent: automationAccount
  properties: {
    parameters: {}
    runbook: {
      name: 'resource-shutdown'
    }
    schedule: {
      name: 'weekdays-end-of-day'
    }
  }
  dependsOn:[resourceShutdownRunbook,weekdaysEndOfDaySchedule]
}

resource resourceBringupRunbookSchedule 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = {
  name: guid('resource-bringup-schedule')
  parent: automationAccount
  properties: {
    parameters: {}
    runbook: {
      name: 'resource-bringup'
    }
    schedule: {
      name: 'weekdays-start-of-day'
    }
  }
  dependsOn:[resourceBringupRunbook,weekdaysStartOfDaySchedule]
}

