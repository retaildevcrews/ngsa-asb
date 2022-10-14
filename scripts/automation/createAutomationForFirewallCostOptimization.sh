#!/bin/bash

function CollectInputParameters(){
  if [[ "$#" -ne 5 ]]; then
      echo "Please provide the 1. Automation Resource Group Name, 2. Location, 3. Automation Account Name, 4. Subscription Name.  5.  Core ASB Resource Group Name  You passed in "$#" parameters."
      exit 1
  else 
    export AutomationResourceGroupName=$1
    export Location=$2
    export AutomationAccountName=$3
    export Subscription=$4
    export Sku='Basic'
    export ASBResourceGroupCore=rg-$5
    export IdentityName='mi_wcnp_automation'

    # export AssigneeObjectId=$4
    # export ResourceGroupNameWithFirewall=$6
    # export vnetName=$7
    # export firewallName=$8
    # export pip_name1=$9
    # export pip_name2=$10
    # export pip_name_default=$11
    # export UAMI=$12
    # export update=$13
  fi
}

function SetSubscription(){
  echo
  echo "Setting subscription to $1..."
  az account set --subscription $1
  echo "Completed setting Subscription to $1."
  echo
}

function UpgradeAzureCLI() {
  # upgrade to latest version of Azure CLI
  echo "Upgrading to latest version of Azure CLI..."
  az upgrade --output none 
  echo "Completed updating Azure CLI version: $(az --version | grep azure-cli | awk '{print $2}')"
}

function AddAzureCLIExtension() {
  az config set extension.use_dynamic_install=yes_without_prompt --output none
    
  # Install or update Azure CLI automation extension
  if [[ $(az extension list --query "[?name=='automation']")=false ]];
  then
    echo "Installing Azure CLI Automation extension..."
    az extension add --name automation --output none
    echo "Completed installing Azure CLI Automation extension version: $(az extension list --query "[?name=='automation'].version" -o tsv)."
  else
    echo "Updating Azure CLI Automation extension"
    az extension update --name automation --output none
    echo "Completed updating Azure CLI Automation extension version: $(az extension list --query "[?name=='automation'].version" -o tsv)."
  fi
  # configure Azure CLI to disallow dynamic installation of
  # extensions without prompts
  az config set extension.use_dynamic_install=yes_prompt --output none
}

function CreateResourceGroup(){
  function CreateGroup(){
    echo "Creating Resource Group $1..."
    if [ $(az group exists --name $1) = true ]; then 
      echo "Resource Group $1 already exists."
    else
      echo "Creating resource group $1 in $2..."
      az group create -n $1 -l $2
      echo "Completed creating resource group $1 in $2."
    fi
  }
  echo "Creating Resource Groups..."
  CreateGroup $1 $2
  echo "Completed Creating Resource Groups."
}

function CreateAzureAutomationAccount(){
  echo "Creating Azure Automation Account $AutomationAccountName in Resource Group $AutomationResourceGroupName..."
  if [[ $(az automation account list --resource-group $AutomationResourceGroupName --query "[?name=='$AutomationAccountName'] | length(@)") > 0 ]]; then
      echo "$AutomationAccountName exists, please review, and choose a different name if appropriate."

  else
      echo "Creating Azure Automation Account $AutomationAccountName..."
      
      az automation account create --automation-account-name $AutomationAccountName --location $Location --sku $Sku --resource-group $AutomationResourceGroupName
      #$Assignee_Id=
      echo "Complated creating Azure Automation Account $AutomationAccountName."
  fi
  echo "Completed creating Azure Automation Account $AutomationAccountName in Resource Group $AutomationResourceGroupName."
}

function CreateUserAssignedManagedIdentity(){
  echo "Creating User-Assigned Managed Identity $IdentityName..."
  az identity create --resource-group $AutomationResourceGroup --name $IdentityName
  echo "Completed created User-Assigned Managed Identity $IdentityName in $AutomationResourceGroup."
}

function AssignUserAssignedManagedIdentity(){
  echo "Assigning User-Assigned Managed Identity $IdentityName to $Subscription..."
  az role assignment create --assignee "$IdentityName" --role "Microsoft.Network/azureFirewalls" --subscription "$Subscription"
  echo "Completed Assigning User-Assigned Managed Identity $IdentityName to $Subscription."
}

function AssignUserAssignedManagedIdentityToAutomationAccount(){
  echo "Assigning User-Assigned Managed Identity $IdentityName to $AutomationAccountName in $AutomationResourceGroup..."
  az automation account identity assign --resource-group $AutomationResourceGroup --name $AutomationAccountName --identity $IdentityName
  echo "Completed assigning User-Assigned Managed Identity $IdentityName to $AutomationAccountName in $AutomationResourceGroup."
}

function CreateAzureAutomationPowerShellRunbook(){
  if [[ $(az automation runbook list --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --query "[?name=='$PowerShellRunbookName'] | length(@)") > 0 ]]; then
      echo "$PowerShellRunbookName exists, please review, and choose a different name if appropriate."
  else
      echo "Creating PowerShell Runbook $PowerShellRunbookName in $AutomationResourceGroup for $AutomationAccountName..."
      az automation runbook create --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --name $PowerShellRunbookName --runbook-type PowerShell --description $PowerShellRunbookDescription --log-progress --log-debug --log-error --log-output --output-folder $PowerShellRunbookOutputFolder
      echo "Completed creating PowerShell Runbook $PowerShellRunbookName in $AutomationResourceGroup for $AutomationAccountName."
  fi
}

function PublishRunbook(){
  echo "Uploading Runbook Content $RunbookName to $AutomationAccountName in $AutomationResourceGroup..."
  az automation runbook publish --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --name $RunbookName --type PowerShell --log-progress --description $RunbookDescription --runbook-content   az automation runbook publish --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --name $RunbookName --type PowerShell --log-progress --description $RunbookDescription --runbook-content "./FirewallToggle.ps1"
  echo "Completed uploading Runbook Content $RunbookName to $AutomationAccountName in $AutomationResourceGroup"
}


function main(){
  echo "Starting Azure Automation Infrastructure creation script..."
  CollectInputParameters $1 $2 $3 $4
  UpgradeAzureCLI
  AddAzureCLIExtension
  SetSubscription $Subscription
  CreateResourceGroup $AutomationResourceGroupName $Location
  CreateAzureAutomationAccount
  CreateAzureAutomationPowerShellRunbook
  CreateUserAssignedManagedIdentity
  AssignUserAssignedManagedIdentityToAutomationAccount
  PublishRunbook
  echo "Azure Automation Infrastructure creation script complete."
}

start_time="$(date -u +%s)"
main $1 $2 $3 $4 $5
end_time="$(date -u +%s)"

elapsed="$(($end_time-$start_time))"
eval "echo Elapsed time: $(date -ud "@$elapsed" +'$((%s/3600/24)) days %H hr %M min %S sec')"