#!/bin/bash

# exit when any command fails
set -e

az upgrade

az config set extension.use_dynamic_install=yes_without_prompt
  
# Install or update Azure CLI automation extension
if [[ $(az extension list --query "[?name=='automation']") = false ]];
then
  az extension add --name automation
else
  az extension update --name automation
fi

# configure Azure CLI to disallow dynamic installation of
# extensions without prompts
az config set extension.use_dynamic_install=yes_prompt

if [ $(az group exists --name $AutomationResourceGroup) = false ]; then
    az group create --name $AutomationResourceGroup --location $Location
fi

if [[ $(az automation account list --resource-group $AutomationResourceGroup --query "[?name=='$AutomationAccountName'] | length(@)") > 0 ]]; then
    echo "$AutomationResourceGroup exists, please review, "
    echo " and choose a different name if appropriate."

else
    echo "Creating Resource Group $AutomationResourceGroup..."
    az automation account create --automation-account-name $AutomationAccountName --location $Location --sku $Sku --resource-group $AutomationResourceGroup
fi

az identity create --resource-group $AutomationResourceGroup --name $IdentityName
az role assignment create --assignee "$Assignee" --role "Microsoft.Network/azureFirewalls" --subscription "$Subscription"