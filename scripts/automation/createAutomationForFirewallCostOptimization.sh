#!/bin/bash

function CollectInputParameters(){
  if [[ "$#" -ne 10 ]]; then
      echo "You passed in "$#" parameters.  10 are required."
      exit 1
  else 
    export AutomationResourceGroupName=$1
    export Location=$2
    export AutomationAccountName=$3
    export Subscription=$4
    export ASBResourceGroupCore=$5
    export IdentityName=$6
    export Sku=$7
    export PowerShellRunbookFileName=$8
    export PowerShellRunbookName=$9
    export PowerShellRunbookDescription=${10}
  fi
}

function SetSubscription(){
  echo "Setting subscription to $Subscription..."
  az account set --subscription $Subscription --output none
  echo "Completed setting Subscription to $Subscriptiond."
  echo
}

function UpgradeAzureCLI() {
  # upgrade to latest version of Azure CLI
  echo "Upgrading to latest version of Azure CLI..."
  az upgrade --output none 
  echo "Completed updating Azure CLI version: $(az --version | grep azure-cli | awk '{print $2}')"
  echo
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
  echo
}

function CreateResourceGroup(){
  function CreateGroup(){
    echo "Creating Resource Group $AutomationResourceGroupName..."
    if [ $(az group exists --name $AutomationResourceGroupName) = true ]; then 
      echo "Resource Group $AutomationResourceGroupName already exists."
      exit;
    else
      echo "Creating resource group $AutomationResourceGroupName in $Location..."
      az group create -n $AutomationResourceGroupName -l $Location  --output none
      echo "Completed creating resource group $AutomationResourceGroupName in $Location."
    fi
  }
  echo "Creating Resource Groups..."
  CreateGroup $AutomationResourceGroupName $Location
  echo "Completed Creating Resource Groups."
  echo
}

function CreateAzureAutomationAccount(){
  echo "Creating Azure Automation Account $AutomationAccountName in Resource Group $AutomationResourceGroupName..."
  if [[ $(az automation account list --resource-group $AutomationResourceGroupName --query "[?name=='$AutomationAccountName'] | length(@)") > 0 ]]; then
      echo "$AutomationAccountName exists, please review, and choose a different name if appropriate."
      exit;

  else
      echo "Creating Azure Automation Account $AutomationAccountName..."
      
      az automation account create --automation-account-name $AutomationAccountName --location $Location --sku $Sku --resource-group $AutomationResourceGroupName  --output none
      echo "Complated creating Azure Automation Account $AutomationAccountName."
  fi
  echo "Completed creating Azure Automation Account $AutomationAccountName in Resource Group $AutomationResourceGroupName."
  echo
}

function CreateUserAssignedManagedIdentity(){
  echo "Creating User-Assigned Managed Identity $IdentityName in $AutomationResourceGroupName..."
  az identity create --resource-group $AutomationResourceGroupName --name $IdentityName  --output none
  echo "Completed created User-Assigned Managed Identity $IdentityName in $AutomationResourceGroupName."
  echo
}

function AssignUserAssignedManagedIdentity(){
  export Identity=$(az identity list -o tsv --query "[].{id:id, principalId: principalId} | [? contains(id, $IdentityName]".id)
  export PrincipalId=$(az identity list -o tsv --query "[].{id:id, principalId: principalId} | [? contains(id, $IdentityName]".principalId)
  export RoleName=$(az role definition list -o tsv --query "[].{roleName:roleName} | [? contains(roleName, Network Contributor].roleName")

  echo "Assigning User-Assigned Managed Identity $IdentityName to $Subscription in resource group $AutomationResourceGroupName..."
  az role assignment create --assignee-object-id $PrincipalId --role "Network Contributor" --subscription $Subscription  --output none
  echo "Completed Assigning User-Assigned Managed Identity $IdentityName to $Subscription in resource group $AutomationResourceGroupName."
  echo
}

function CreateAzureAutomationPowerShellRunbook(){
  if [[ $(az automation runbook list --resource-group $AutomationResourceGroupName --automation-account-name $AutomationAccountName --query "[?name=='$PowerShellRunbookName'] | length(@)") > 0 ]]; then
      echo "$PowerShellRunbookName exists, please review, and choose a different name if appropriate."
  else
      echo "Creating PowerShell Runbook $PowerShellRunbookName in $AutomationResourceGroupName for $AutomationAccountName..."
      az automation runbook create --resource-group $AutomationResourceGroupName --automation-account-name $AutomationAccountName --name $PowerShellRunbookName --type "PowerShell" --description "$PowerShellRunbookDescription"  --output none
      echo "Completed creating PowerShell Runbook $PowerShellRunbookName in $AutomationResourceGroupName for $AutomationAccountName."
  fi
  echo
}

function UpdateRunbook(){
  echo "Uploading Runbook Content from $PowerShellRunbookFileName to $PowerShellRunbookName to $AutomationAccountName Automation Account in $AutomationResourceGroupName resource group..."
    
  export repositoryName=$(basename -s .git `git config --get remote.origin.url`)    
  export file=$(cat "scripts/automation/$PowerShellRunbookFileName")

  az automation runbook replace-content --automation-account-name $AutomationAccountName --resource-group $AutomationResourceGroupName --name $PowerShellRunbookName --content @"scripts/automation/$PowerShellRunbookFileName"
    
  echo "Completed uploading Runbook Content from $PowerShellRunbookFileName to $PowerShellRunbookName to $AutomationAccountName Automation Account in $AutomationResourceGroupName resource group." 
  echo
}

function PublishRunbook(){
  echo "Publishing Runbook Content from $PowerShellRunbookFileName to $PowerShellRunbookName to $AutomationAccountName Automation Account in $AutomationResourceGroupName resource group..."

  az automation runbook publish --resource-group $AutomationResourceGroupName --automation-account-name $AutomationAccountName --name $PowerShellRunbookName
    
  echo "Completed publishing Runbook Content from $PowerShellRunbookFileName to $PowerShellRunbookName to $AutomationAccountName Automation Account in $AutomationResourceGroupName resource group." 
  echo
}


function main(){
  echo "Starting Azure Automation Infrastructure creation script..."
  echo
  CollectInputParameters $1 $2 $3 $4 $5 $6 $7 $8 $9 ${10}
  UpgradeAzureCLI
  AddAzureCLIExtension
  SetSubscription
  CreateResourceGroup
  CreateAzureAutomationAccount
  CreateAzureAutomationPowerShellRunbook
  CreateUserAssignedManagedIdentity
  UpdateRunbook
  PublishRunbook
  echo "Azure Automation Infrastructure creation script complete."
  echo
}

start_time="$(date -u +%s)"
main $1 $2 $3 $4 $5 $6 $7 $8 $9 ${10}
end_time="$(date -u +%s)"

elapsed="$(($end_time-$start_time))"
eval "echo Elapsed time: $(date -ud "@$elapsed" +'$((%s/3600/24)) days %H hr %M min %S sec')"