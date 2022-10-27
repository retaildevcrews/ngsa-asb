#!/bin/bash

# Retries a command on failure.
# $1 - the max number of attempts
# $2... - the command to run
function retry() {
    local -r -i max_attempts="$1"; shift
    local -r cmd="$@"
    local -i attempt_num=1

    until $cmd
    do
        if (( $attempt_num == $max_attempts ))
        then
            echo "Attempt $attempt_num failed and there are no more attempts left!"
            exit;
        else
            echo "Attempt $attempt_num failed! Trying again in $attempt_num seconds..."
            sleep $(( $attempt_num++ ))
        fi
    done
}

 function CollectInputParameters(){
  source ./scripts/automation/firewallAutomationForCostOptimization.variables.sh
}

function SetSubscription(){
  # Arguments: 
    # parameter position 1 = Subscription Name
    # parameter position 2 = Tenant Id

  echo
  echo "Setting the Azure subscription to ${1}..."
  
  $(az login --tenant "${2}" --output none)
  $(az account set --subscription "${1}" --output none)
  
  echo "Completed setting the Azure subscription to ${1}."
  echo
}

function UpgradeAzureCLI() {
  echo
  # upgrade to latest version of Azure CLI
  echo "Upgrading to latest version of Azure CLI..."

  $(az upgrade --yes --only-show-errors --output none)

  echo "Completed upgrading to latest version of Azure CLI."
  echo
}

function AddAzureCLIExtension() {
  echo
  $(az config set extension.use_dynamic_install=yes_without_prompt --output none --only-show-errors)
    
  # Install or update Azure CLI automation extension
  if [[ $(az extension list --query "[?name=='automation']")=false ]]; then
    echo "Installing Azure CLI Automation extension..."

    $(az extension add --name automation --output none --only-show-errors)

    echo "Completed installing Azure CLI Automation extension version: $(az extension list --query "[?name=='automation'].version" -o tsv)."

  else
    echo "Updating Azure CLI Automation extension"

    $(az extension update --name automation --output none --only-show-errors)

    echo "Completed updating Azure CLI Automation extension version: $(az extension list --query "[?name=='automation'].version" -o tsv)."
  fi


  # Install or update Azure CLI automation extension
  if [[ $(az extension list --query "[?name=='ad']")=false ]]; then
    echo "Installing Azure CLI ad extension..."

    $(az extension add --name ad --output none --only-show-errors)

    echo "Completed installing Azure CLI ad extension version: $(az extension list --query "[?name=='ad'].version" -o tsv)."

  else
    echo "Updating Azure CLI ad extension"

    $(az extension update --name ad --output none --only-show-errors)

    echo "Completed updating Azure CLI ad extension version: $(az extension list --query "[?name=='ad'].version" -o tsv)."
  fi


  # configure Azure CLI to disallow dynamic installation of
  # extensions without prompts
  $(az config set extension.use_dynamic_install=yes_prompt --output none)
  echo
}

function CreateResourceGroup(){   
  # Arguments: 
    # parameter position 1 = Automation Resource Group
    # parameter position 2 = ASB_FW_Location

  echo
  if [ $(az group exists --name "${1}") = true ]; then 
    echo "Resource Group $1 already exists."
    exit;
  else
    echo "Creating resource group $1 in $2..."
    $(az group create -n "${1}" -l "${2}" --output none)
    echo "Completed creating resource group $1 in $2."
  fi
  echo
}

function CreateAzureAutomationAccount(){
  # Arguments: 
    # parameter position 1 = Automation Account Name
    # parameter position 2 = Automation Resource Group
    # parameter position 3 = ASB_FW_Location
    # parameter position 4 = ASB_FW_Sku

  echo
  echo "Creating Azure Automation Account $1 in Resource Group $2..."
  
  if [[ $(az automation account list --resource-group "${2}" --query "[?name=='${1}'] | length(@)") > 0 ]]; then
  
      echo "$1 exists, please review, and choose a different name if appropriate."
      exit;
  else
    echo "Creating Azure Automation Account $1..."
     
    $(az automation account create --automation-account-name "${1}" --location "${3}" --sku "${4}" --resource-group "${2}" --output none)
          
    echo "Completed creating Azure Automation Account $1."
  fi

  echo "Completed creating Azure Automation Account $1 in Resource Group $2."
  echo
}

function CreateAzureAutomationPowerShellRunbook(){
  # Arguments: 
    # parameter position 1 = rubbook Name
    # parameter position 2 = Automation Resource Group
    # parameter position 3 = Automation Account Name
    # parameter position 4 = Tenant Id
    # parameter position 5 = Subscription Id
    

      echo "Creating PowerShell Runbook $1 in $2 for $3..."

      pwsh -command "Install-Module -Name Az.Automation; Connect-AzAccount -UseDeviceAuthentication -Tenant $4 -Subscription $5; New-AzAutomationRunbook -Type 'PowerShell' -AutomationAccountName "${3}" -Name "${1}" -ResourceGroupName "${2}";"

      echo "Completed creating PowerShell Runbook $1 in $3 for $4."
  
  echo
}

function CreateUserAssignedManagedIdentity(){
  # Arguments: 
    # parameter position 1 = User-Assigned Managed Identity Name
    # parameter position 2 = Automation Resource Group

  echo
  echo "Creating User-Assigned Managed Identity $1 in resource group $2..."

  $(az identity create --resource-group "${2}" --name "${1}" --output none)

  echo "Completed created User-Assigned Managed Identity $1 in resource group $2."
  echo
}

function UpdateAzureAutomationAccountToAllowSystemAssignedIdentity() {
  # Arguments: 
    # parameter position 1 = Automation Account Name
    # parameter position 2 = Automation Resource Group
    # parameter position 3 = Subscription Id
    # parameter position 4 = Tenant Id
    # parameter position 5 = User=Assigned Managed Identity Name
    # parameter position 6 = Automation Account Principal Id

  echo
  echo "Assigning role Managed Identity Operator to the System Assigned Identity for automation account $1 in resource group $2, within subscription id $3..."

  # a name for our azure ad app
  appName="${1}-application"

  # The name of the app role that the managed identity should be assigned to.
  appRoleName='Managed Identity Operator' # For example, MyApi.Read.All

  pwsh --command "Connect-AzAccount -UseDeviceAuthentication -Tenant $4 -Subscription $3; Set-AzAutomationAccount -AssignUserIdentity /subscriptions/$3/resourcegroups/$2/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$5 -ResourceGroupName $2 -Name $1 -AssignSystemIdentity;"

  $(az role assignment create --assignee "${6}" --role "{$appRoleName}" --scope "/subscriptions/${3}/resourcegroups/${2}/providers/Microsoft.Automation/automationAccounts/${1}" --output none)
    
  echo "Completed assigning role Managed Identity Operator to the System Assigned Identity for automation account $1 in resource group $2, within subscription id $3."
  echo
}

function AssignIdentityRole(){
  # Arguments: 
    # parameter position 1 = User-Assigned Managed Identity Principal Id 
    # parameter position 2 = User-Assigned Managed Identity Name
    # parameter position 3 = Automation Resource Group
    # parameter position 4 = Subscription Name
    # parameter position 5 = Assignee Principal Type
    # parameter position 6 = Role to Assign
 
  echo
  echo "Assigning roles to user-assigned managed identity $2 in subscription $4, in resource group $3, with ID $1 with role $6..."

  $(az role assignment create --assignee-object-id "${1}" --assignee-principal-type "${5}" --role "${6}" --subscription "${4}" --output none)
    
  echo "Completed assigning roles to user-assigned managed identity $2 in subscription $4, in resource group $3, with ID $1 with role $6."
  echo
}

function ImportPowerShellRunbookContent(){ 
  # Arguments: 
    # parameter position 1 = rubbook Name
    # parameter position 2 = Automation Resource Group
    # parameter position 3 = Runbook Content File Path and File
    # parameter position 4 = Automation Account Name
  
  echo
  echo "Uploading runbook content from $3 to $1 to $4 automation account in $2 resource group..."
    
  $(az automation runbook replace-content --automation-account-name "${4}" --resource-group "${2}" --name "${1}" --content "${3}" --output none)
    
  echo "Completed uploading runbook content from $3 to $1 to $4 automation account in $2 resource group."
  echo
}

function PublishRunbook(){
  # Arguments: 
    # parameter position 1 = rubbook Name
    # parameter position 2 = Automation Resource Group
    # parameter position 3 = Automation Account Name

  echo
  echo "Publishing runbook content from $1 to $3 automation account in $2 resource group..."

  $(az automation runbook publish --resource-group "${2}" --automation-account-name "${3}" --name "${1}" --output none)
    
  echo "Completed publishing runbook content from $1 to $3 automation account in $2 resource group."
  echo
}

function main(){
  local subscriptionId=$(az account show --query id --output tsv)
  
  CollectInputParameters

  local automationResourceGroup="rg-${ASB_FW_Base_NSGA_Name}-${ASB_FW_Base_Automation_System_Name}-${ASB_FW_Environment}"

  local runbookName="rb-${ASB_FW_Base_NSGA_Name}-${ASB_FW_Base_Automation_System_Name}-${ASB_FW_Environment}"
  local runbookDescription="${ASB_FW_PowerShell_Runbook_Description}"
  local runbookFileName="${ASB_FW_PowerShell_Runbook_File_Name}"
  local runbookFilePath="./scripts/automation/"
  local runbookFilePathAndName=@"${runbookFilePath}${runbookFileName}"

  echo
  echo "-------------------------------------------------------------------"
  echo "  Starting Azure Automation Infrastructure creation script...      "
  echo "-------------------------------------------------------------------"
  echo

  # Establishing prerequisites and environment variables imports
  UpgradeAzureCLI
  AddAzureCLIExtension

  # Set the subscription to the one specified in the parameters
  SetSubscription $ASB_FW_Subscription_Name $ASB_FW_Tenant_Id

  CreateResourceGroup $automationResourceGroup $ASB_FW_Location

  local automationAccountName="aa-${ASB_FW_Base_NSGA_Name}-${ASB_FW_Base_Automation_System_Name}-${ASB_FW_Environment}"
  
  local userAssignedManagedIdentityName="mi-${ASB_FW_Base_NSGA_Name}-${ASB_FW_Base_Automation_System_Name}-${ASB_FW_Environment}"

  CreateUserAssignedManagedIdentity $userAssignedManagedIdentityName $automationResourceGroup

  local identityPrincipalId=$(az identity list --resource-group "${automationResourceGroup}" --query "[?name=='${userAssignedManagedIdentityName}'].{name:name,principalId:principalId}|[0].principalId" --output tsv)

  CreateAzureAutomationAccount $automationAccountName $automationResourceGroup $ASB_FW_Location $ASB_FW_Sku

  local automationAccountPrincipalId=$(az automation account list --resource-group "${automationResourceGroup}" --query "[?name=='${automationAccountName}'].identity.{principalId:principalId}|[0].principalId" --output tsv)

  CreateAzureAutomationPowerShellRunbook $runbookName $automationResourceGroup $automationAccountName $ASB_FW_Tenant_Id $subscriptionId

  UpdateAzureAutomationAccountToAllowSystemAssignedIdentity $automationAccountName $automationResourceGroup $subscriptionId $ASB_FW_Tenant_Id $userAssignedManagedIdentityName $automationAccountPrincipalId


  AssignIdentityRole $identityPrincipalId $userAssignedManagedIdentityName $automationResourceGroup $ASB_FW_Subscription_Name "ServicePrincipal" "Monitoring Contributor"
  AssignIdentityRole $identityPrincipalId $userAssignedManagedIdentityName $automationResourceGroup $ASB_FW_Subscription_Name "ServicePrincipal" "Contributor"  
 
  # Set the subscription to the one specified in the parameters
  #SetSubscription $ASB_FW_Subscription_Name $ASB_FW_Tenant_Id

  ImportPowerShellRunbookContent $runbookName $automationResourceGroup $runbookFilePathAndName $automationAccountName

  PublishRunbook $runbookName $automationResourceGroup $automationAccountName

  echo
  echo "-------------------------------------------------------------------"
  echo "  Completed Azure Automation Infrastructure creation.              "
  echo "-------------------------------------------------------------------"
  echo
}

#  executionStartTime="$(date -u +%s)"

# Call the main controller function to begin the script
main

# executionEndTime="$(date -u +%s)"
# elapsedExecutionTime="$(($executionEndTime-$elapsedExecutionTime))"

# eval "echo Elapsed time: $(date -ud "@$elapsedExecutionTime" +'$((%s/3600/24)) days %H hr %M min %S sec')"