# Web Application Firewall (WAF) Allocation/De-Allocation Automation

Azure Firewall has [costs (Azure Firewall pricing link)](https://azure.microsoft.com/en-gb/pricing/details/azure-firewall/#pricing) associated with it which can be optimized by allocating and de-allocating the firewall when appropriate.  Below describes the mechanism to implement an Azure Automation Runbook that will allocate and de-allocate the firewall on a schedule as well as enable and disable the alerts associated with this activity to minimize nonessential systems communications.

## Acronym List

| Term | Acronym | Notes |
| :---- | :----: | :---- |
| Commandline Interface | CLI | | 
|  |  |  |
## Prerequisites

Before proceeding verify  the environment is configured correct to execute the commands necessary below

- Azure CLI 2.0 or greater [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

- Azure CLI Extension for Automation [Install Azure CLI Extensions](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-list)

- Azure CLI Extension for Monitor [Install Azure CLI Extensions](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-list)

- *Azure Powershell modules for Linux* [Install Modules](/allocationAutomationForFirewall.md#Install-Powershell-Modules)

*The Azure CLI Automation extension is in an experimental stage.  Currently it does not implement all functionality needed.  As a result the the Az Module, specifically for automation and authentication can be used at the time of writing.*

- [*Azure CLI Extension - Automation*](https://github.com/Azure/azure-cli-extensions/tree/main/src/automation)
- [Azure PowerShell Az Modules](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-9.0.0)

## Installation Instructions

Once all prerequisites have been installed and updated the following steps will illistrate establishing the environment for enabling and disabling the Azure Firewall.  

### 1. Set Subscription & Tenant

Authenticate into the correct tenant and subscription.  Below is the Azure Commandline Interface (CLI)

``` bash

echo "Setting subscription to $subscription in tenant $tenantId..."

az login --tenant $tenantId
az account set --subscription $subscription

echo "Completed setting subscription to $subscription in tenant $tenantId."

```

### Install Powershell Modules

The following command should be executed from the Codespace terminal to ensure the modules are installed.  These commands can be executed from an authenticated Azure Powershell terminal from within the Azure Codespace environment.

#### 3. PowerShell Modules

```PowerShell

Write-Host "Installing & Importing Azure Powershell Az Module for Automation."

Install-Module -Name Az.Automation -Force | out-null
Import-Module -Name Az.Automation -Force | out-null

Write-Host "Installing & Importing Azure Powershell Az Module for Monitor."

Install-Module -Name Az.Monitor -Force | out-null
Import-Module -Name Az.Monitor -Force | out-null

Write-Host "Completed installing & importing Azure Powershell Az Modules for Authentication and Monitor."

```

### 4. Install Azure CLI Assets

Follow the steps below to assure the prerequisites are installed and up-to-date and all necessary extensions are installed.

### 5. Azure CLI Upgrade

```bash
# check the version of the Azure CLI installed.  
az version
# if < than 2.4.0 
echo "Upgrading to latest version of Azure CLI..."
az upgrade --output none 
echo "Completed updating "
echo "Azure CLI version: $(az --version | grep azure-cli | awk '{print $2}""
```

### 6. Azure CLI Extensions

```bash
az config set extension.use_dynamic_install=yes_without_prompt --output none
    
# Install or update Azure CLI automation extension
if [[ $(az extension list --query "[?name=='automation']")=false ]]; then

  echo "Installing Azure CLI Automation extension..."

  az extension add --name automation --output none
  
  echo "Completed installing Azure CLI Automation extension version:"
  echo "$(az extension list --query "[?name=='automation'].version" -o tsv)."

else
  echo "Updating Azure CLI Automation extension"

  az extension update --name automation --output none

  echo "Completed updating Azure CLI Automation extension version:"
  echo "$(az extension list --query "[?name=='automation'].version" -o tsv)."
fi
# configure Azure CLI to disallow dynamic installation of
# extensions without prompts
az config set extension.use_dynamic_install=yes_prompt --output none
```

### Parameters Needed to Proceed

| Parameter Name | Example Value | Rules for Naming |
| -------------- | :-----------: | ---------------- |
||||
| ASB_FW_TenantId | 72f988bf-86f1-41af-91ab-2d7cd011db47 ||
| ASB_FW_SubscriptionId | 3b25180b-416b-4b73-92e2-8668f62075d5 |  |
| ASB_FW_Sku | Basic |  |
| ASB_FW_Automation_Resource_Group_Name | rg-trfalls-firewall-automation |  |
| ASB_FW_Resource_Group_Core | rg-centraus-hub-dev |  |
| ASB_FW_Location | eastus |  |
| ASB_FW_Automation_Account_Name | aa-trfalls-automation |  |
| ASB_FW_PowerShell_Runbook_Name | rb-trfalls-firewall-automation |  |
| ASB_FW_PowerShell_Runbook_File_Name | firewallAutomationForCostOptimization.ps1 |  |
| ASB_FW_Identity_Name | mi-trfalls-firewall-automation |  |
| ASB_FW_PowerShell_Runbook_Description | This runbook automates the allocation and de-allocation of a firewall for the purposes of scheduling." # Description for the runbook. |  |
| ASB_FW_PowerShell_Runbook_Output_Folder | . |  |
| ASB_FW_Environment | dev |  |
| ASB_FW_Base_Schedule_Name_Start | wcnp-fw-start- |  |
| ASB_FW_Base_Schedule_Name_Stop | wcnp-fw-stop- |  |
| AssigneeObjectId              | 00000000-0000-0000-0000-000000000000 | [Az Role Assignment Assignee-Object-Id](https://learn.microsoft.com/en-us/cli/azure/role/assignment?view=azure-cli-latest#az-role-assignment-create-optional-parameters)                                                                                                                                                                                                              |
| vnetName                      |           vnet-cetntral-hub          | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| firewallName                  |             fw-centralus             | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| pip_name1                     |          pip-fw-centralus-01         | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| pip_name2                     |          pip-fw-centralus-02         | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| pip_name_default              |       pip-fw-centralus-default       | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| UAMI                          |    mi-ngsa-firewall-automation-dev   | User-Assigned Managed Identity name.

## Infrastructure & Assets Creation List

The following infrastructure assets should be established in the subscription with the Azure Firewall(s) to be managed once all aspects of this document are fulfilled.  Though six (6) items are listed, technically one (1) item is an import of content to the body of the Azure Automation Runbook so this item will not show up in the portal without deeper investigation.  

|     | Resource                                  |                                                                                       Links                                                                                      | Description                                                                                                                                                                 |
| :-: | :---------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|  1. | Resource Group                            |                                                 [link](https://learn.microsoft.com/en-us/cli/azure/manage-azure-groups-azure-cli)                                                | Create "sibling" resource group in subscription for Azure Automation infrastructure.                                                                                        |
|  2. | Automation Account                        |                     [link](https://learn.microsoft.com/en-us/azure/templates/microsoft.automation/automationaccounts?pivots=deployment-language-arm-template)                    | Create an Automation Account that will execute the automation.                                                                                                              |
|  3. | User-Assigned Managed Identity            | [link](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-manage-user-assigned-managed-identities?pivots=identity-mi-methods-azcli) | Create an identity for the Automation Account.                                                                                                                              |
|  4. | Automation Runbook with Powershell        |                                      [link](https://learn.microsoft.com/en-us/azure/automation/automation-runbook-types#powershell-runbooks)                                     | Create a Runbook of type Powershell.                                                                                                                                        |
|  5. | Powershell Content in Runbook             |                               [link](https://learn.microsoft.com/en-us/powershell/module/az.automation/import-azautomationrunbook?view=azps-8.3.0)                               | Upload [pre-defined Powershell content](../automation/FirewallToggle.ps1) into the Runbook body.                                                                            |
|  6. | Automation Schedule(s) _using Powershell_ |                               [link](https://learn.microsoft.com/en-us/powershell/module/az.automation/import-azautomationrunbook?view=azps-8.3.0)                               | Create the schedules that will execute the Firewall automation.  These had to be created using Powershell instead of the Azure CLI.  No equivalent behavior has been found. |                                |

### Create Resource Group

```bash
#Check if automation resource group exists, and create it if it does not.
if [[ $(az group exists --name $AutomationResourceGroupName)=false ]]; then
  az group create --name $AutomationResourceGroupName --location $Location
fi
```

### Create Azure Automation Account

```bash
echo "Creating Azure Automation Account $AutomationAccountName in Resource Group $AutomationResourceGroupName..."
if [[ $(az automation account list --resource-group $AutomationResourceGroupName --query "[?name=='$AutomationAccountName'] | length(@)") > 0 ]]; then
    echo "$AutomationAccountName exists, please review, and choose a different name if appropriate."

else
    echo "Creating Azure Automation Account $AutomationAccountName..."
    
    az automation account create --automation-account-name $AutomationAccountName --location $Location --sku $Sku --resource-group $AutomationResourceGroupName

    echo "Completed creating Azure Automation Account $AutomationAccountName."
fi

echo "Completed creating Azure Automation Account $AutomationAccountName in Resource Group $AutomationResourceGroupName."
```

### Create User-Assigned Managed Identity

```bash
echo "Creating User-Assigned Managed Identity $IdentityName in $AutomationResourceGroupName..."
az identity create --resource-group $AutomationResourceGroupName --name $IdentityName
echo "Completed created User-Assigned Managed Identity $IdentityName in $AutomationResourceGroupName."
```

### Assign Role to User-Assigned Managed Identity

```bash
export Identity=$(az identity list -o tsv --query "[].{id:id, principalId: principalId} | [? contains(id, $IdentityName]".id)

export PrincipalId=$(az identity list -o tsv --query "[].{id:id, principalId: principalId} | [? contains(id, $IdentityName]".principalId)

export RoleName=$(az role definition list -o tsv --query "[].{roleName:roleName} | [? contains(roleName, Network Contributor].roleName")

echo "Assigning User-Assigned Managed Identity $IdentityName to $Subscription in resource group $AutomationResourceGroupName..."
az role assignment create --assignee-object-id $PrincipalId --role "Network Contributor" --subscription $Subscription
echo "Completed Assigning User-Assigned Managed Identity $IdentityName to $Subscription in resource group $AutomationResourceGroupName."$AutomationResourceGroupName."
```

### Create Automation Powershell Runbook

```bash
if [[ $(az automation runbook list --resource-group $AutomationResourceGroupName --automation-account-name $AutomationAccountName --query "[?name=='$PowerShellPowerShellRunbookName'] | length(@)") > 0 ]]; then
    echo "$PowerShellPowerShellRunbookName exists, please review, and choose a different name if appropriate."
else
    echo "Creating PowerShell Runbook $PowerShellPowerShellRunbookName in $AutomationResourceGroupName for $AutomationAccountName..."
    az automation runbook create --resource-group $AutomationResourceGroupName --automation-account-name $AutomationAccountName --name $PowerShellPowerShellRunbookName --runbook-type PowerShell --description $PowerShellRunbookDescription
    echo "Completed creating PowerShell Runbook $PowerShellPowerShellRunbookName in $AutomationResourceGroupName for $AutomationAccountName."
fi
```

### Publish Runbook

```bash
echo "Uploading Runbook Content from $PowerShellRunbookFileName to $PowerShellRunbookName to $AutomationAccountName in $AutomationResourceGroupName..."
  
export repositoryName=$(basename -s .git `git config --get remote.origin.url`)
  
export file=$(cat automation/$PowerShellRunbookFileName) 

az automation runbook replace-content --automation-account-name $AutomationAccountName --resource-group $AutomationResourceGroupName --name $PowerShellRunbookName --content $file

az automation runbook publish --resource-group $AutomationResourceGroupName --automation-account-name $AutomationAccountName --name $PowerShellRunbookName
  
echo "Completed uploading Runbook Content from $PowerShellRunbookFileName to $PowerShellRunbookName to $AutomationAccountName in $AutomationResourceGroupName" 
```

### Create Schedule (PowerShell)

<!-- ```bash
# echo "Creating Schedule for $PowerShellRunbookName controlled by $AutomationAccountName automation account, in $AutomationResourceGroupName recourse group..."
  
#  az automation  --automation-account-name $AutomationAccountName --resource-group $AutomationResourceGroupName --name $PowerShellRunbookName --content $file
 
  
# echo "Completed Creating Schedule for $PowerShellRunbookName controlled by $AutomationAccountName automation account, in $AutomationResourceGroupName recourse group."
``` -->

```powershell

  source ./automation/variables.ps1
  Connect-AzAccount -UseDeviceAuth
  Select-AzSubscription -SubscriptionName $Env:Subscription

  $StartTime = Get-Date "13:00:00"
  $EndTime = $StartTime.AddYears(3)

  New-AzAutomationSchedule -AutomationAccountName $Env:AutomationAccountName -Name "$Env:BaseScheduleNameStart$Env:Asb_Environment" -StartTime $StartTime -ExpiryTime $EndTime -DayInterval 1 -ResourceGroupName $Env:AutomationResourceGroupName

  New-AzAutomationSchedule -AutomationAccountName $Env:AutomationAccountName -Name "$Env:BaseScheduleNameStop$Env:Asb_Environment" -StartTime $StartTime -ExpiryTime $EndTime -DayInterval 1 -ResourceGroupName $Env:AutomationResourceGroupName

```
# TODO: prefix environment variables.  

### Associate Schedule with Runbook

```powershell
    Register-AzAutomationScheduledRunbook -AutomationAccountName $Env:AutomationAccountName -RunbookName $Env:PowerShellRunbookName -ScheduleName "$Env:BaseScheduleNameStart$Env:Asb_Environment" -ResourceGroupName $Env:AutomationResourceGroupName -Parameters @{"resourceGroupName"="$Env:AutomationResourceGroupName";"automationAccount"="$Env:AutomationAccountName";"subscriptionName"="$Env:Subscription";"vnetName"="vnet-cetntral-hub";"fw_name"="fw-centralus";"pip_name1"="pip-fw-centralus-01";"pip_name2"="pip-fw-centralus-02";"pip_name_default"="pip-fw-centralus-default";"UAMI"="$Env:IdentityName";"update"="start"}

    Register-AzAutomationScheduledRunbook -AutomationAccountName $Env:AutomationAccountName -RunbookName $Env:PowerShellRunbookName -ScheduleName "$Env:BaseScheduleNameStop$Env:Asb_Environment" -ResourceGroupName $Env:AutomationResourceGroupName -Parameters @{"resourceGroupName"="$Env:AutomationResourceGroupName";"automationAccount"="$Env:AutomationAccountName";"subscriptionName"="$Env:Subscription";"vnetName"="vnet-cetntral-hub";"fw_name"="fw-centralus";"pip_name1"="pip-fw-centralus-01";"pip_name2"="pip-fw-centralus-02";"pip_name_default"="pip-fw-centralus-default";"UAMI"="$Env:IdentityName";"update"="stop"}
```

### Reference

- [Microsoft - FAQ - How can I stop and start azure firewalls](https://learn.microsoft.com/en-us/azure/firewall/firewall-faq#how-can-i-stop-and-start-azure-firewall)
- [WCNP - Automated FW malloc & free](https://github.com/retaildevcrews/wcnp/issues/1003)
- [WCNP - Migrate Infrastructure](https://github.com/retaildevcrews/wcnp/issues/815)
- [Microsoft - Automation Services - Azure Automation](https://learn.microsoft.com/en-us/azure/automation/automation-services#azure-automation)
- [Microsoft - Create Automation PowerShell RunBook using managed identity](https://learn.microsoft.com/en-us/azure/automation/learn/powershell-runbook-managed-identity)
