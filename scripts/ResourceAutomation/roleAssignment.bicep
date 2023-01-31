targetScope='subscription'

@description('Name of user assigned automation account')
param roleAssignmentName string 

@description('Id of the user principal')
param userPrincipalId string

@description('Rolde definition id')
param roleDefId string

resource AA_RoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleAssignmentName
  scope: subscription()
  properties: {
    principalId: userPrincipalId
    roleDefinitionId:roleDefId
    principalType: 'ServicePrincipal'
  }
}
