targetScope='resourceGroup'

@description('Name of user assigned managed identity')
param AA_Name string = 'aa-automation'

@description('Name of location')
param location string = resourceGroup().location

@description('Name of user assigned managed identity')
param MI_Name string = 'mi-automation'

@description('Role definition ID')
param RA_role_def_id string = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

@description('Role definition ID')
param RA_module string = 'ra-module'

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
    roleDefId: RA_role_def_id
    userPrincipalId:automationMI.properties.principalId
   }
}



