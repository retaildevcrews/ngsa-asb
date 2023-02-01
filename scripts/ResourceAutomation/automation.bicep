targetScope = 'subscription'

@description('Unique portion of automation account resource names')
param AA_accountSuffix string='automation-test'

@description('Name of resource group')
param RG_Name string = 'rg-${AA_accountSuffix}'

@description('Name of user assigned automation account')
param AA_Name string = 'aa-${AA_accountSuffix}'

@description('Name of user assigned managed identity')
param MI_Name string = 'mi-${AA_accountSuffix}'

@description('Name of location')
@allowed([ 'centralus', 'eastus', 'westus3' ])
param location string = 'eastus'

resource automationRG 'Microsoft.Resources/resourceGroups@2021-04-01' = { name: RG_Name, location: location }

module automationAccountModule 'automationAccount.bicep' = {
  name: MI_Name
  scope: resourceGroup(RG_Name)
  params:{
    location:location
    AA_Name:AA_Name
    MI_Name:MI_Name
  }
  dependsOn:[automationRG]
}




