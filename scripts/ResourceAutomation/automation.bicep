targetScope = 'subscription'

@description('Name of resource group')
@minLength(1)
@maxLength(90)
param RG_Name string = 'rg-automation'

@description('Name of location')
@allowed([ 'centralus', 'eastus', 'westus3' ])
param location string = 'eastus'

@description('Name of user assigned automation account')
param AA_Name string = 'aa-automation'

@description('Name of user assigned managed identity')
param MI_Name string = 'mi-automation'



resource automationRG 'Microsoft.Resources/resourceGroups@2021-04-01' = { name: RG_Name, location: location }

module automationAccountModule 'automationAccount.bicep' = {
  name: MI_Name
  scope: resourceGroup(RG_Name)
  params:{
    location:location
    AA_Name:AA_Name
    MI_Name:MI_Name
  }
}




