@description('Name for the container group')
param name string = 'ci-cert-automation'

@description('Location for the automation resources')
param location string = resourceGroup().location

@description('Container image to deploy')
param image string = 'ghcr.io/retaildevcrews/cert-automation'

@description('Name of the managed identity to use for the container group')
param identityName string = 'mi-fdpo-automation'

@description('Name of the DNS Zone to use for domain validation')
param azureDnsZone string = 'austinrdc.dev'

@description('Name of the DNS Zone Resource Group')
param azureDnsResourceGroup string = 'dns-rg'

@description('Email address to use for Lets Encrypt registration')
param certbotAccountEmail string

@description('Name that certbot will use in the file name when saving the certificate')
param certbotCertname string = 'austinrdc-dev'

@description('Domain to request a certificate for')
param certbotDomain string = '*.austinrdc.dev'

@description('Name of the secret to store the full chain certificate in Key Vault')
param kvFullChainSecretName string

@description('Name of the Key Vault to store the certificate information')
param kvName string

@description('Name of the secret to store the certificate in PFX format')
param kvPfxSecretName string

@description('Name of the secret to store the certificate private key in Key Vault')
param kvPrivateKeySecretName string

@description('Lets Encrypt environment to use when generating the certificate')
@allowed([
  'staging'
  'production'
])
param letsEncryptEnvironment string = 'staging'

@description('Number of days before a certificate expires to renew it')
param numDaysToRenew string = '30'

resource automationIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityName
}

resource certAutomationContainerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: name
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${automationIdentity.id}': {}
    }
  }
  properties: {
    containers: [
      {
        name: 'cert-automation'
        properties: {
          command: ['certbot', '--version']
          environmentVariables: [
            { name: 'AZURE_DNS_RESOURCE_GROUP', value: azureDnsResourceGroup }
            { name: 'AZURE_DNS_ZONE', value: azureDnsZone }
            { name: 'CERTBOT_ACCOUNT_EMAIL', value: certbotAccountEmail }
            { name: 'CERTBOT_CERTNAME', value: certbotCertname }
            { name: 'CERTBOT_DOMAIN', value: certbotDomain }
            { name: 'KV_FULL_CHAIN_SECRET_NAME', value: kvFullChainSecretName }
            { name: 'KV_NAME', value: kvName }
            { name: 'KV_PFX_SECRET_NAME', value: kvPfxSecretName }
            { name: 'KV_PRIVATE_KEY_SECRET_NAME', value: kvPrivateKeySecretName }
            { name: 'LETS_ENCRYPT_ENVIRONMENT', value: letsEncryptEnvironment }
            { name: 'NUM_DAYS_TO_RENEW', value: numDaysToRenew }
          ]
          image: image
          ports: []
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
        }
      }
    ]
    osType: 'Linux'
    priority: 'Regular'
    restartPolicy: 'Never'
    sku: 'Standard'
  }
}
