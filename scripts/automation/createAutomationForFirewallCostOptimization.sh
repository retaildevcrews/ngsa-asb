#!/bin/bash

 function CollectInputParameters(){
  source ./scripts/automation/firewallAutomationForCostOptimization.variables.sh

}

function SetSubscription(){
  echo
  echo "Setting ASB_FW_Subscription_Id to $ASB_FW_Subscription_Id..."

  az account set --subscription $ASB_FW_Subscription_Id --output none
  
  echo "Completed setting ASB_FW_Subscription_Id to $ASB_FW_Subscription_Id."
  echo
}

function UpgradeAzureCLI() {
  # upgrade to latest version of Azure CLI
  echo "Upgrading to latest version of Azure CLI..."

  az upgrade --output none --yes --only-show-errors

  echo "Completed upgrading to latest version of Azure CLI."
  echo
}

function AddAzureCLIExtension() {
  az config set extension.use_dynamic_install=yes_without_prompt --output none --only-show-errors
    
  # Install or update Azure CLI automation extension
  if [[ $(az extension list --query "[?name=='automation']")=false ]]; then
    echo "Installing Azure CLI Automation extension..."

    az extension add --name automation --output none --only-show-errors

    echo "Completed installing Azure CLI Automation extension version: $(az extension list --query "[?name=='automation'].version" -o tsv)."

  else
    echo "Updating Azure CLI Automation extension"

    az extension update --name automation --output none --only-show-errors

    echo "Completed updating Azure CLI Automation extension version: $(az extension list --query "[?name=='automation'].version" -o tsv)."
  fi
  # configure Azure CLI to disallow dynamic installation of
  # extensions without prompts
  az config set extension.use_dynamic_install=yes_prompt --output none
  echo
}

function CreateResourceGroup(){
  function CreateGroup(){
    echo "Creating Resource Group ..."
    if [ $(az group exists --name $ASB_FW_Resource_Group_Name_for_Automation) = true ]; then 
      echo "Resource Group $ASB_FW_Resource_Group_Name_for_Automation already exists."
      exit;
  
    else
      echo "Creating resource group $ASB_FW_Resource_Group_Name_for_Automation in $ASB_FW_Location..."
      az group create -n $ASB_FW_Resource_Group_Name_for_Automation -l $ASB_FW_Location --output none
      echo "Completed creating resource group $ASB_FW_Resource_Group_Name_for_Automation in $ASB_FW_Location."
    fi
  }
  
  echo "Creating Resource Groups..."
  
  CreateGroup $ASB_FW_Resource_Group_Name_for_Automation $ASB_FW_Location

  echo "Completed Creating Resource Groups."
  echo
}

function CreateAzureAutomationAccount(){
  echo "Creating Azure Automation Account $ASB_FW_Automation_Account_Name in Resource Group $ASB_FW_Resource_Group_Name_for_Automation..."
  
  if [[ $(az automation account list --resource-group $ASB_FW_Resource_Group_Name_for_Automation --query "[?name=='$ASB_FW_Automation_Account_Name'] | length(@)") > 0 ]]; then
      echo "$ASB_FW_Automation_Account_Name exists, please review, and choose a different name if appropriate."
      exit;

  else
      echo "Creating Azure Automation Account $ASB_FW_Automation_Account_Name..."
      
      az automation account create --automation-account-name $ASB_FW_Automation_Account_Name --location $ASB_FW_Location --sku $ASB_FW_Sku --resource-group $ASB_FW_Resource_Group_Name_for_Automation  --output none
      echo "Complated creating Azure Automation Account $ASB_FW_Automation_Account_Name."
  fi
  echo "Completed creating Azure Automation Account $ASB_FW_Automation_Account_Name in Resource Group $ASB_FW_Resource_Group_Name_for_Automation."
  echo
}

function CreateUserAssignedManagedIdentity(){
  echo "Creating User-Assigned Managed Identity $ASB_FW_Identity_Name in $ASB_FW_Resource_Group_Name_for_Automation..."

  az identity create --resource-group $ASB_FW_Resource_Group_Name_for_Automation --name $ASB_FW_Identity_Name  --output none

  echo "Completed created User-Assigned Managed Identity $ASB_FW_Identity_Name in $ASB_FW_Resource_Group_Name_for_Automation."
  echo
}

function AssignUserAssignedManagedIdentity(){
  export Identity=$(az identity list -o tsv --query "[].{id:id, principalId: principalId} | [? contains(id, $ASB_FW_Identity_Name]".id)
  export PrincipalId=$(az identity list -o tsv --query "[].{id:id, principalId: principalId} | [? contains(id, $ASB_FW_Identity_Name]".principalId)
  export RoleName=$(az role definition list -o tsv --query "[].{roleName:roleName} | [? contains(roleName, Network Contributor].roleName")

  echo "Assigning User-Assigned Managed Identity $ASB_FW_Identity_Name to $ASB_FW_Subscription_Id in resource group $ASB_FW_Resource_Group_Name_for_Automation..."
  az role assignment create --assignee-object-id $PrincipalId --role "Network Contributor" --ASB_FW_Subscription_Id $ASB_FW_Subscription_Id  --output none
  echo "Completed Assigning User-Assigned Managed Identity $ASB_FW_Identity_Name to $ASB_FW_Subscription_Id in resource group $ASB_FW_Resource_Group_Name_for_Automation."
  echo
}

function CreateAzureAutomationPowerShellRunbook(){
  if [[ $(az automation runbook list --resource-group $ASB_FW_Resource_Group_Name_for_Automation --automation-account-name $ASB_FW_Automation_Account_Name --query "[?name=='$ASB_FW_PowerShell_Runbook_Name'] | length(@)") > 0 ]]; then
      echo "$ASB_FW_PowerShell_Runbook_Name exists, please review, and choose a different name if appropriate."
  else
      echo "Creating PowerShell Runbook $ASB_FW_PowerShell_Runbook_Name in $ASB_FW_Resource_Group_Name_for_Automation for $ASB_FW_Automation_Account_Name..."
      az automation runbook create --resource-group $ASB_FW_Resource_Group_Name_for_Automation --automation-account-name $ASB_FW_Automation_Account_Name --name $ASB_FW_PowerShell_Runbook_Name --type "PowerShell" --description "$ASB_FW_PowerShell_Runbook_Description"  --output none
      echo "Completed creating PowerShell Runbook $ASB_FW_PowerShell_Runbook_Name in $ASB_FW_Resource_Group_Name_for_Automation for $ASB_FW_Automation_Account_Name."
  fi
  echo
}

function UpdateRunbook(){
  echo "Uploading Runbook Content from $ASB_FW_PowerShell_Runbook_File_Name to $ASB_FW_PowerShell_Runbook_Name to $ASB_FW_Automation_Account_Name Automation Account in $ASB_FW_Resource_Group_Name_for_Automation resource group..."
    
  export repositoryName=$(basename -s .git `git config --get remote.origin.url`)    
  export file=$(cat "scripts/automation/$ASB_FW_PowerShell_Runbook_File_Name")

  az automation runbook replace-content --automation-account-name $ASB_FW_Automation_Account_Name --resource-group $ASB_FW_Resource_Group_Name_for_Automation --name $ASB_FW_PowerShell_Runbook_Name --content @"scripts/automation/$ASB_FW_PowerShell_Runbook_File_Name"
    
  echo "Completed uploading Runbook Content from $ASB_FW_PowerShell_Runbook_File_Name to $ASB_FW_PowerShell_Runbook_Name to $ASB_FW_Automation_Account_Name Automation Account in $ASB_FW_Resource_Group_Name_for_Automation resource group." 
  echo
}

function PublishRunbook(){
  echo "Publishing Runbook Content from $ASB_FW_PowerShell_Runbook_File_Name to $ASB_FW_PowerShell_Runbook_Name to $ASB_FW_Automation_Account_Name Automation Account in $ASB_FW_Resource_Group_Name_for_Automation resource group..."

  az automation runbook publish --resource-group $ASB_FW_Resource_Group_Name_for_Automation --automation-account-name $ASB_FW_Automation_Account_Name --name $ASB_FW_PowerShell_Runbook_Name
    
  echo "Completed publishing Runbook Content from $ASB_FW_PowerShell_Runbook_File_Name to $ASB_FW_PowerShell_Runbook_Name to $ASB_FW_Automation_Account_Name Automation Account in $ASB_FW_Resource_Group_Name_for_Automation resource group." 
  echo
}


function main(){
  echo "Starting Azure Automation Infrastructure creation script..."
  echo
  CollectInputParameters
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
main
end_time="$(date -u +%s)"

elapsed="$(($end_time-$start_time))"
eval "echo Elapsed time: $(date -ud "@$elapsed" +'$((%s/3600/24)) days %H hr %M min %S sec')"