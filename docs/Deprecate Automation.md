# Automation Resource Decommission Instructions

The following instructions will guide to decomissioning the target Automated Resources such as Firewall, Cluster and Application Gateway.

## Login to Azure

```bash
az login 

###  show your Azure accounts
az account list -o table

###  select the Azure subscription if necessary
az account set -s {subscription name or Id}
```

## Set input variable values

```bash

# Automation SP name 
export servicePrincipalName='agw-automation-sp'

# Key vault name where client and secrets are stored
export keyVaultName='kv-aks-jxdthrti3j3qu'

# Key vault resource group name
export keyVaultRGName='rg-wcnp-dev'


# Get the current Susbcription Id 
export subscriptionId=$(az account show -o tsv --query id)


# Get Service principal ClientId 
export automationClientId=$(az ad sp list --all --filter "displayname eq '${servicePrincipalName}'" --query "[].appId" -o tsv)

```

## Delete Automation Resource group

The following command will delete the target automation resources group along with all child resources.

```bash
export firewallAutomationRG='rg-wcnp-firewall-automation-dev'

# Delete resource group along with all child resources e.g. Automation Account, ManagedIdentity, Runbooks 
az group delete --name $firewallAutomationRG

```

## Delete Service Principal, Role Assignments and Secrets from Key Vault


```bash

# Deleting role assignment 
az role assignment delete --assignee $automationClientId --role "Managed Identity Operator" --scope "/subscriptions/${subscriptionId}"

# Deleting role assignment 
az role assignment delete --assignee $automationClientId --role "Automation Contributor" --scope "/subscriptions/${subscriptionId}"

# Get servicePrincipalId
export servicePrincipalId=$(az ad sp list --all --filter "displayname eq '${servicePrincipalName}'" --query "[].id" -o tsv)

# Delete SP
az ad sp delete --id $servicePrincipalId

# Get appRegistrationlId
export appRegistrationlId=$(az ad app list --all --filter "displayname eq '${servicePrincipalName}'" --query "[].id" -o tsv)

# Delete AppRegistration
az ad app delete --id $appRegistrationlId

# Give logged in user access to key vault
az keyvault set-policy --secret-permissions delete --object-id $(az ad signed-in-user show --query id -o tsv) -n $keyVaultName -g $keyVaultRGName

# Delete Automation service principal secrets
az keyvault secret delete --name "AutomationClientSecret" --vault-name $keyVaultName
az keyvault secret delete --name "AutomationClientId" --vault-name $keyVaultName

# Remove logged in user's access to key vault
az keyvault delete-policy --object-id $(az ad signed-in-user show --query id -o tsv) -n $keyVaultName -g $keyVaultRGName

```
