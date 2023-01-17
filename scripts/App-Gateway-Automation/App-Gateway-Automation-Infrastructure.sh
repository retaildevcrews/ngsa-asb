#!/bin/bashASB_AGW

function CollectInputParameters(){
  source ./scripts/App-Gateway-Automation/App-Gateway-Automation-Infrastructure-Variables.env
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

function CreateAzureAutomationPowerShellRunbook(){
  # Arguments: 
    # parameter position 1 = runbook Name
    # parameter position 2 = Automation Resource Group
    # parameter position 3 = Automation Account Name
    # parameter position 4 = location
    # parameter position 5 = runbook description

      echo "Creating PowerShell Runbook $1 in $2 for $3..."

      $(az automation runbook create --automation-account-name "${3}" --resource-group "${2}" --name "${1}" --type "PowerShell" --location "${4}" --description "${5}" --output none)
      
      echo "Completed creating PowerShell Runbook $1 in $2 for $3."
  
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
    # parameter position 1 = runbook Name
    # parameter position 2 = Automation Resource Group
    # parameter position 3 = Automation Account Name

  echo
  echo "Publishing runbook content from $1 to $3 automation account in $2 resource group..."

  $(az automation runbook publish --resource-group "${2}" --automation-account-name "${3}" --name "${1}" --output none)
    
  echo "Completed publishing runbook content from $1 to $3 automation account in $2 resource group."
  echo
}

function CreateSchedule(){
  # Arguments: 
    # parameter position 1 = AutomationClientId
    # parameter position 2 = AutomationClientSecret

  pwsh --command "./scripts/App-Gateway-Automation/App-Gateway-Automation-Schedule-Creation.ps1 ${1} ${2}"
}

function GrantSignedInUserAccessToKeyVault(){
  # give logged in user access to key vault
  az keyvault set-policy --secret-permissions get --object-id $(az ad signed-in-user show --query id -o tsv) -n $ASB_KV_Name -g $ASB_KV_ResourceGroupName -o tsv
}

function RemoveSignedInUserAccessToKeyVault(){
  # Remove logged in user's access to key vault
  az keyvault delete-policy --object-id $(az ad signed-in-user show --query id -o tsv) -n $ASB_KV_Name -g $ASB_KV_ResourceGroupName -o tsv
}

function main(){
  local subscriptionId=$(az account show --query id --output tsv)
  
  CollectInputParameters
  
  local automationResourceGroup="$ASB_AGW_Automation_Account_Resource_Group"

  local runbookName="rb-${ASB_AGW_Deployment_Name}-agw-automation-${ASB_AGW_Environment}"
  local runbookDescription="Runbook to schedule restarting of app gateways"
  local runbookFileName="$ASB_AGW_PowerShell_Runbook_File_Name"
  local runbookFilePath="./scripts/App-Gateway-Automation/"
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
  SetSubscription $ASB_AGW_Subscription_Name $ASB_AGW_Tenant_Id

  local automationAccountName="$ASB_AGW_Automation_Account_Name"
  
  local userAssignedManagedIdentityName="$ASB_AGW_UAMI_Name"

  local identityPrincipalId=$(az identity list --resource-group ${automationResourceGroup} --query "[?name=='${userAssignedManagedIdentityName}'].{name:name,principalId:principalId}|[0].principalId" --output tsv)

  CreateAzureAutomationPowerShellRunbook $runbookName $automationResourceGroup $automationAccountName $location # $ASB_AGW_Tenant_Id $subscriptionId

  # Grant SignedInUser Access to KeyVault 
  GrantSignedInUserAccessToKeyVault

  # Read secrets from key vault
  local automationClientId=$(az keyvault secret show --subscription $ASB_AGW_Subscription_Name --vault-name $ASB_KV_Name -n AutomationClientId --query value -o tsv)
  local automationClientSecret=$(az keyvault secret show --subscription $ASB_AGW_Subscription_Name --vault-name $ASB_KV_Name -n AutomationClientSecret --query value -o tsv)

  # Remove SignedInUser Access to KeyVault 
  RemoveSignedInUserAccessToKeyVault

  ImportPowerShellRunbookContent $runbookName $automationResourceGroup $runbookFilePathAndName $automationAccountName

  PublishRunbook $runbookName $automationResourceGroup $automationAccountName

  CreateSchedule $automationClientId $automationClientSecret $runbookName

  
  echo
  echo "-------------------------------------------------------------------"
  echo "  Completed Azure App Gateway Automation Infrastructure creation.  "
  echo "-------------------------------------------------------------------"
  echo
}

main