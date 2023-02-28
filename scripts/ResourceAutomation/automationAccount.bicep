targetScope='resourceGroup'

@description('Log analytics workspace id')
param logAnalyticsWorkspaceId string

@description('URL of the bringup/shutdown script')
param clusterGwStartStopRunbookURL string

@description('Firewall URL of the bringup/shutdown script')
param firewallStartStopRunbookURL string

@description('Name of location')
param location string = resourceGroup().location

@description('Name of automation account')
param AA_Name string 

@description('Name of user assigned managed identity')
param MI_Name string 

@description('Time Zone for Schedules')
param scheduleTimezone string

@description('Start of day datetime for schedule')
param scheduleStartOfDayTime string='08:10:00'

@description('End of day datetime for schedule')
param scheduleEndOfDayTime string='20:00:00' 

@description('Start of day datetime for schedule')
param scheduleStartOfDayDateTime string = '${dateTimeAdd(utcNow(), 'P1D', 'yyyy-MM-dd')}T${scheduleStartOfDayTime}-06:00'

@description('End of day datetime for schedule')
param scheduleEndOfDayDateTime string = '${dateTimeAdd(utcNow(), 'P1D', 'yyyy-MM-dd')}T${scheduleEndOfDayTime}-06:00'

@description('Firewall start of day datetime for schedule')
param firewallScheduleStartOfDayTime string='07:10:00'

@description('Firewall start of day datetime for schedule')
param firewallScheduleStartOfDayDateTime string = '${dateTimeAdd(utcNow(), 'P1D', 'yyyy-MM-dd')}T${firewallScheduleStartOfDayTime}-06:00'

@description('Log Verbose Messages in Runbooks')
param logVerbose bool = false

@description('Log Progress Messages in Runbooks')
param logProgress bool = false

@description('Array of objects that define what needs to be automated  - gateway, and cluster (assumes they are in the same resource group)')
param resourcesToAutomate array

@description('Array of Firewall objects that need to be automated')
param firewallsToAutomate array

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

// -------------------------- Cluster and Appication Gateway setup ---------------------------------------------

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
    startTime: scheduleStartOfDayDateTime 
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
    startTime: scheduleEndOfDayDateTime
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
  name: guid('resource-bringup-schedule',resourceToAutomate.clusterName,AA_Name)
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
  name: guid('resource-shutdown-schedule',resourceToAutomate.clusterName,AA_Name)
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
      disabled: '$true'
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

// -------------------------- Firewall setup ---------------------------------------------

resource firewallWeekdaysStartOfDaySchedule 'Microsoft.Automation/automationAccounts/schedules@2022-08-08' = {
  name: 'firewallWeekdays-start-of-day'
  parent: automationAccount
  properties: {
    advancedSchedule: {
      weekDays: [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday' ]
    }
    description: 'Schedule that runs every weekday at specified time'
    interval: 1
    frequency: 'Week'
    startTime: firewallScheduleStartOfDayDateTime 
    expiryTime: '9999-12-31T17:59:00-06:00'
    timeZone: scheduleTimezone
  }
}

resource firewallWeekdaysEndOfDaySchedule 'Microsoft.Automation/automationAccounts/schedules@2022-08-08' = {
  name: 'firewallWeekdays-end-of-day'
  parent: automationAccount
  properties: {
    advancedSchedule: {
      weekDays: [ 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday' ]
    }
    description: 'Schedule that runs every weekday at specified time'
    interval: 1
    frequency: 'Week'
    startTime: scheduleEndOfDayDateTime
    expiryTime: '9999-12-31T17:59:00-06:00'
    timeZone: scheduleTimezone
  }
}

resource firewallBringupRunbooks 'Microsoft.Automation/automationAccounts/runbooks@2022-08-08' = [for firewallToAutomate in firewallsToAutomate: {
  name: 'runbook-fw-${firewallToAutomate.firewallLocation}-${firewallToAutomate.environment}-bringup'
  location: location
  parent: automationAccount
  properties: {
    description: 'Runbook to bring up fw-${firewallToAutomate.firewallLocation}-${firewallToAutomate.environment} at the beginning of the day'
    logProgress: logProgress
    logVerbose: logVerbose
    publishContentLink: {
      uri: firewallStartStopRunbookURL
    }
    runbookType: 'PowerShell'
  }
}]

resource firewallBringupRunbookSchedules 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = [for firewallToAutomate in firewallsToAutomate: {
  name: guid('resource-bringup-schedule','fw-${firewallToAutomate.firewallLocation}-${firewallToAutomate.environment}',AA_Name)
  parent: automationAccount
  properties: {
    parameters: {
      tenantId: tenant().tenantId
      subscriptionName: subscription().displayName
      automationAccountResourceGroup: resourceGroup().name
      managedIdentityClientId: automationMI.properties.clientId
      resource_Group_Name_with_Firewall: firewallToAutomate.resourceGroup
      resource_Group_Name_with_Alerts: firewallToAutomate.resourceGroupWithAlerts
      resource_Group_Name_for_Automation: resourceGroup().name
      automation_Account_Name: AA_Name
      vnet_Name: 'vnet-${firewallToAutomate.firewallLocation}-hub'
      firewall_Name: 'fw-${firewallToAutomate.firewallLocation}'
      pip_Name1: 'pip-fw-${firewallToAutomate.firewallLocation}-01'
      pip_Name2: 'pip-fw-${firewallToAutomate.firewallLocation}-02'
      pip_Name_Default: 'pip-fw-${firewallToAutomate.firewallLocation}-default'
      action: 'start'
      environment: firewallToAutomate.environment
      location: firewallToAutomate.firewallLocation
    }
    runbook: {
      name: 'runbook-fw-${firewallToAutomate.firewallLocation}-${firewallToAutomate.environment}-bringup'
    }
    schedule: {
      name: 'firewallWeekdays-start-of-day'
    }
  }
  dependsOn:[firewallBringupRunbooks,firewallWeekdaysStartOfDaySchedule]
}]


resource firewallShutdownRunbooks 'Microsoft.Automation/automationAccounts/runbooks@2022-08-08' = [for firewallToAutomate in firewallsToAutomate: {
  name: 'runbook-fw-${firewallToAutomate.firewallLocation}-${firewallToAutomate.environment}-shutdown'
  location: location
  parent: automationAccount
  properties: {
    description: 'Runbook to shut down fw-${firewallToAutomate.firewallLocation}-${firewallToAutomate.environment} at the end of the day'
    logProgress: logProgress
    logVerbose: logVerbose
    publishContentLink: {
      uri: firewallStartStopRunbookURL
    }
    runbookType: 'PowerShell'
  }
}]


resource firewallShutdownRunbookSchedules 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = [for firewallToAutomate in firewallsToAutomate: {
  name: guid('resource-shutdown-schedule','fw-${firewallToAutomate.firewallLocation}-${firewallToAutomate.environment}',AA_Name)
  parent: automationAccount
  properties: {
    parameters: {
      tenantId: tenant().tenantId
      subscriptionName: subscription().displayName
      automationAccountResourceGroup: resourceGroup().name
      managedIdentityClientId: automationMI.properties.clientId
      resource_Group_Name_with_Firewall: firewallToAutomate.resourceGroup
      resource_Group_Name_with_Alerts: firewallToAutomate.resourceGroupWithAlerts
      resource_Group_Name_for_Automation: resourceGroup().name
      automation_Account_Name: AA_Name
      vnet_Name: 'vnet-${firewallToAutomate.firewallLocation}-hub'
      firewall_Name: 'fw-${firewallToAutomate.firewallLocation}'
      pip_Name1: 'pip-fw-${firewallToAutomate.firewallLocation}-01'
      pip_Name2: 'pip-fw-${firewallToAutomate.firewallLocation}-02'
      pip_Name_Default: 'pip-fw-${firewallToAutomate.firewallLocation}-default'
      action: 'stop'
      environment: firewallToAutomate.environment
      location: firewallToAutomate.firewallLocation
    }
    runbook: {
      name: 'runbook-fw-${firewallToAutomate.firewallLocation}-${firewallToAutomate.environment}-shutdown'
    }
    schedule: {
      name: 'firewallWeekdays-end-of-day'
    }
  }
  dependsOn:[firewallShutdownRunbooks,firewallWeekdaysEndOfDaySchedule]
}]
  
output aaMIPrincipalId string =automationMI.properties.principalId
