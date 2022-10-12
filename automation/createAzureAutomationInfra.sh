#!/bin/bash

function CollectInputParameters(){
  if [ "$#" -lt 4 ] || [ "$#" -gt 4 ]; then
      echo "Please provide the 1. Automation Resource Group Name, 2. Location, 3. Automation Account Name, 4. Subscription Name.  You passed in $# parameters."
      exit 1
  else 
    export AutomationResourceGroupName = $1
    export Location = $2
    export AutomationAccountName = $3
    export Subscription = $4
    export Sku = 'Basic'
    
    # export AssigneeObjectId = $4
    # export ResourceGroupNameWithFirewall = $6
    # export vnetName = $7
    # export firewallName = $8
    # export pip_name1 = $9
    # export pip_name2 = $10
    # export pip_name_default = $11
    # export UAMI = $12
    # export update = $13
  fi
}

function SetSubscription(){
  echo "Setting subscription to $Subscription..."
  az account set --subscription $Subscription
  echo "Subscription set to $Subscription"
}

function UpgradeAzureCLI() {
  # upgrade to latest version of Azure CLI
  echo "Upgrading to latest version of Azure CLI"
  az upgrade --yes --output none 
  echo "Updated Azure CLI version: $(az --version | grep azure-cli | awk '{print $2}')"
}

function AddAzureCLIExtension() {
  az config set extension.use_dynamic_install=yes_without_prompt --output none
    
  # Install or update Azure CLI automation extension
  if [[ $(az extension list --query "[?name=='automation']") = false ]];
  then
    echo "Installing Azure CLI Automation extension"
    az extension add --name automation
    echo "Installed Azure CLI Automation extension version: $(az extension list --query "[?name=='automation'].version" -o tsv)"
  else
    echo "Updating Azure CLI Automation extension"
    az extension update --name automation
    echo "Updated Azure CLI Automation extension version: $(az extension list --query "[?name=='automation'].version" -o tsv)"
  fi

  # configure Azure CLI to disallow dynamic installation of
  # extensions without prompts
  az config set extension.use_dynamic_install=yes_prompt --output none
}

function CreateResourceGroup() {
  if [ $(az group exists --name $AutomationResourceGroup) = false ]; then
    echo "Creating resource group $AutomationResourceGroup"
    az group create --name $AutomationResourceGroup --location $Location
    echo "Created resource group $AutomationResourceGroup in $Location"  
  fi
}

function CreateAzureAutomationAccount(){
  if [[ $(az automation account list --resource-group $AutomationResourceGroup --query "[?name=='$AutomationAccountName'] | length(@)") > 0 ]]; then
      echo "$AutomationAccountName exists, please review, "
      echo " and choose a different name if appropriate."

  else
      echo "Creating Azure Automation Account $AutomationAccountName..."
      $Assignee_Id = az automation account create --automation-account-name $AutomationAccountName --location $Location --sku $Sku --resource-group $AutomationResourceGroup
      echo "Created Azure Automation Account $AutomationAccountName with Assignee_Id $Assignee_Id"
      az account list --query "[].{name:name, id:id}" --output tsv
  fi
}

function CreateAzureAutomationPowerShellRunbook(){
  if [[ $(az automation runbook list --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --query "[?name=='$PowerShellRunbookName'] | length(@)") > 0 ]]; then
      echo "$PowerShellRunbookName exists, please review, "
      echo " and choose a different name if appropriate."

  else
      echo "Creating PowerShell Runbook $PowerShellRunbookName..."
      az automation runbook create --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --name $PowerShellRunbookName --runbook-type PowerShell --description $PowerShellRunbookDescription --log-progress --log-debug --log-error --log-output --output-folder $PowerShellRunbookOutputFolder
      echo "Created PowerShell Runbook $PowerShellRunbookName in $AutomationResourceGroup for $AutomationAccountName"
  fi
}

function CreateUserAssignedManagedIdentity(){
  echo "Creating User Assigned Managed Identity $IdentityName..."
  az identity create --resource-group $AutomationResourceGroup --name $IdentityName
  echo "Created User Assigned Managed Identity $IdentityName in $AutomationResourceGroup"
}

function AssignUserAssignedManagedIdentity(){
  echo "Assigning User Assigned Managed Identity $IdentityName to $Subscription..."
  az role assignment create --assignee "$IdentityName" --role "Microsoft.Network/azureFirewalls" --subscription "$Subscription"
  echo "Assigned User Assigned Managed Identity $IdentityName to $Subscription"
}

function AssignUserAssignedManagedIdentityToAutomationAccount(){
  echo "Assigning User Assigned Managed Identity $IdentityName to $AutomationAccountName in $AutomationResourceGroup..."
  az automation account identity assign --resource-group $AutomationResourceGroup --name $AutomationAccountName --identity $IdentityName
  echo "Assigned User Assigned Managed Identity $IdentityName to $AutomationAccountName in $AutomationResourceGroup"
}

function UploadRunbookContent(){
  echo "Uploading Runbook Content $RunbookName to $AutomationAccountName in $AutomationResourceGroup..."
  az automation runbook publish --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --name $RunbookName --type PowerShell --log-progress --description $RunbookDescription --runbook-content $RunbookContent
  echo "Uploaded Runbook Content $RunbookName to $AutomationAccountName in $AutomationResourceGroup"
}


function main(){
  echo "Starting Azure Automation Infrastructure creation script..."
  CollectInputParameters $1 $2 $3 $4
  UpgradeAzureCLI
  AddAzureCLIExtension
  SetSubscription  
  CreateResourceGroup
  CreateAzureAutomationAccount
  #CreateAzureAutomationPowerShellRunbook
  #CreateUserAssignedManagedIdentity
  #AssignUserAssignedManagedIdentityToAutomationAccount
  #UploadRunbookContent
  echo "Azure Automation Infrastructure creation script complete."
}

start_time="$(date -u +%s)"
main
end_time="$(date -u +%s)"

elapsed="$(($end_time-$start_time))"
eval "echo Elapsed time: $(date -ud "@$elapsed" +'$((%s/3600/24)) days %H hr %M min %S sec')"