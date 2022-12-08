#!/bin/bash

function CollectInputParameters(){
  source ./scripts/Firewall-Automation/Firewall-Automation-Infrastructure-Variables.sh
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
  if [[ $(az automation account list --resource-group "${2}" --query "[?name=='${1}'] | length(@)") > 0 ]]; then
  
      echo "$1 exists, please review, and choose a different name if appropriate."
      exit;
  else
    echo "Creating Azure Automation Account $1..."
     
    $(az automation account create --automation-account-name "${1}" --location "${3}" --sku "${4}" --resource-group "${2}" --output none)
          
    echo "Completed creating Azure Automation Account $1."
  fi
  echo
}

function CreateAzureAutomationPowerShellRunbook(){
  # Arguments: 
    # parameter position 1 = rubbook Name
    # parameter position 2 = Automation Resource Group
    # parameter position 3 = Automation Account Name
    # parameter position 4 = location
    # parameter position 5 = runbook description

      echo "Creating PowerShell Runbook $1 in $2 for $3..."

      $(az automation runbook create --automation-account-name "${3}" --resource-group "${2}" --name "${1}" --type "PowerShell" --location "${4}" --description "${5}" --output none)
      
      echo "Completed creating PowerShell Runbook $1 in $2 for $3."
  
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
    # parameter position 5 = User-Assigned Managed Identity Name
  
  echo
  echo "Assigning role Managed Identity Operator to the System Assigned Identity for automation account ${1} in resource group ${2}, within subscription id ${3}..."

  # a name for our azure ad app
  local appName="$1-application"

  # The name of the app role that the managed identity should be assigned to.
  local appRoleName='Managed Identity Operator' # For example, MyApi.Read.All

  # Do assign ManagedIdentity to Automation Account
  pwsh --command "./scripts/Firewall-Automation/Firewall-Automation-SetSystemAssignedIdentity.ps1 ${3} ${2} ${5} ${1}"

  # Get ManagedIdentity Id from automation account, this requires to perform the assign ManagedIdentity to Automation Account step first. 
  local automationAccountPrincipalId=$(az automation account show --automation-account-name "${1}" --resource-group "${2}" --query "identity.principalId" -o tsv)
  
  echo "Automation Account principal id: $automationAccountPrincipalId"

  # Create the role assignment for Automation Account giving 'Managed Identity Operator' permission over 'rg-[deploymentName]-firewall-automation-dev' resource group
  az role assignment create --role "$appRoleName" --assignee $automationAccountPrincipalId --scope "/subscriptions/${3}/resourceGroups/${2}"

  echo "Completed assigning role Managed Identity Operator to the System Assigned Identity for automation account ${1} in resource group ${2}, within subscription id ${3}."

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

function CreateSchedule(){
  pwsh --command "./scripts/Firewall-Automation/Firewall-Automation-Schedule-Creation.ps1"
}

function main(){
  local subscriptionId=$(az account show --query id --output tsv)
  
  CollectInputParameters

  local automationResourceGroup="rg-${ASB_FW_Deployment_Name}-${ASB_FW_Base_Automation_System_Name}-${ASB_FW_Environment}"

  local runbookName="rb-${ASB_FW_Deployment_Name}-${ASB_FW_Base_Automation_System_Name}-${ASB_FW_Environment}"
  local runbookDescription="${ASB_FW_PowerShell_Runbook_Description}"
  local runbookFileName="${ASB_FW_PowerShell_Runbook_File_Name}"
  local runbookFilePath="./scripts/Firewall-Automation/"
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

  local automationAccountName="aa-${ASB_FW_Deployment_Name}-${ASB_FW_Base_Automation_System_Name}-${ASB_FW_Environment}"
  
  local userAssignedManagedIdentityName="mi-${ASB_FW_Deployment_Name}-${ASB_FW_Base_Automation_System_Name}-${ASB_FW_Environment}"

  CreateUserAssignedManagedIdentity $userAssignedManagedIdentityName $automationResourceGroup

  local identityPrincipalId=$(az identity list --resource-group ${automationResourceGroup} --query "[?name=='${userAssignedManagedIdentityName}'].{name:name,principalId:principalId}|[0].principalId" --output tsv)

  CreateAzureAutomationAccount $automationAccountName $automationResourceGroup $ASB_FW_Location $ASB_FW_Sku

  CreateAzureAutomationPowerShellRunbook $runbookName $automationResourceGroup $automationAccountName $location # $ASB_FW_Tenant_Id $subscriptionId

  UpdateAzureAutomationAccountToAllowSystemAssignedIdentity $automationAccountName $automationResourceGroup $subscriptionId $ASB_FW_Tenant_Id $userAssignedManagedIdentityName

  AssignIdentityRole $identityPrincipalId $userAssignedManagedIdentityName $automationResourceGroup $ASB_FW_Subscription_Name "ServicePrincipal" "Monitoring Contributor"
  AssignIdentityRole $identityPrincipalId $userAssignedManagedIdentityName $automationResourceGroup $ASB_FW_Subscription_Name "ServicePrincipal" "Contributor"  
 
  ImportPowerShellRunbookContent $runbookName $automationResourceGroup $runbookFilePathAndName $automationAccountName

  PublishRunbook $runbookName $automationResourceGroup $automationAccountName

  CreateSchedule

  echo
  echo "-------------------------------------------------------------------"
  echo "  Completed Azure Automation Infrastructure creation.              "
  echo "-------------------------------------------------------------------"
  echo
}

main
