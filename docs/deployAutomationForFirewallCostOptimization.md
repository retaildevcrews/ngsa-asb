# Web Application Firewall (WAF) Allocation/De-Allocation Automation

Azure Firewall has [costs (Azure Firewall pricing link)](https://azure.microsoft.com/en-gb/pricing/details/azure-firewall/#pricing) associated with it which can be optimized by allocating and de-allocating the firewall when appropriate.  Below describes the mechanism to implement an Azure Automation Runbook that will allocate and de-allocate the firewall on a schedule as well as enable and disable the alerts associated with this activity to minimize nonessential systems communications.

## Prerequisites

Before proceeding verify  the environment is configured correct to execute the commands necessary below

- Azure CLI 2.0 or greater [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

- Azure CLI Extension for Automation [Install Azure CLI Extensions](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-list)

- Azure CLI Extension for Monitor [Install Azure CLI Extensions](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-list)

- *Azure Powershell modules for Linux* [Install Modules](/allocationAutomationForFirewall.md#Install-Powershell-Modules)

*The Azure CLI Automation extension is in an experimental stage.  Currently it does not implement all functionality needed.  As a result the the Az Module, specifically for automation and authentication can be used at the time of writing.*

- [*Azure CLI Extension - Automation*](https://github.com/Azure/azure-cli-extensions/tree/main/src/automation)
- [Azure PowerShell Az Modules](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-9.0.0)

## Portal

1. Create a resource group within the subscription and tenant that contains the firewalls.  This new resource group will house three resources.
   
   example resource group name: 'rg-asb-firewall-automation-dev'.

   1. Azure user-assigned Managed Identity
   2. Azure Automation Account
   3. Azure PowerShell Runbook

   ```azurecli

    # Log into the tenant
    az login --tenant {tenant Id}

    # Set the subscription desired    
    az account set --subscription {subscription name}
    
    # pass in resource group  name and location
    az group create -name {automation resource group name} -location {location}

   ```

2. Create an Azure Automation Account within the portal or via the CLI command listed below.

  example Azure Automation Account name: 'aa-asb-firewall-automation-dev'

  ```azurecli
  
    # Log into the tenant
    az login --tenant {tenant Id}

    # Set the subscription desired    
    az account set --subscription {subscription name}
  
    az automation account create --automation-account-name {automation account name} --location {location} --sku 'Basic' --resource-group {automation resource group name}

  ```

  1. Navigate it the "Identity" blade in the Azure portal for the Azure Automation Account.
  2. Enable system-assigned Managed Identity
  3. Save.  (for now)

3. Create an Azure user-assigned Managed Identity within the Azure Portal or the Azure CLI.  

  example Azure user-assigned Managed Identity Account name: 'mi-asb-firewall-automation-dev'

   ``` azurecli

    # Log into the tenant
    az login --tenant {tenant Id}

    # Set the subscription desired    
    az account set --subscription {subscription name}

    az identity create --resource-group {automation resource group name} --name {user-assigned managed identity name}

  # a name for our azure ad app
  appName="{automation account name}-application"

  # The name of the app role that the managed identity should be assigned to.
  appRoleName='Managed Identity Operator' # For example, MyApi.Read.All

  pwsh --command "Connect-AzAccount -UseDeviceAuthentication -Tenant {tenant id} -Subscription {subscription Id}; Set-AzAutomationAccount -AssignUserIdentity /subscriptions/{subscription Id}/resourcegroups/{automation resource group name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{user-assigned managed identity name} -ResourceGroupName {automation resource group name} -Name {automation account name} -AssignSystemIdentity;"

  az role assignment create --assignee-object-id {user-assigned managed identity principal id} --assignee-principal-type 'ServicePrincipal' --role 'Monitoring Contributor' --subscription {subscription name}
  az role assignment create --assignee-object-id {user-assigned managed identity principal id} --assignee-principal-type 'ServicePrincipal' --role 'Contributor' --subscription {subscription name}

   ```

   1. Enable "system-assigned managed identity" for the automation account.
      1. This identity will require "Managed Identity Contributor" permissions to allow it access to a user-assigned managed identity created in the subsequently steps.

4. Create an Azure Powershell Runbook from the Azure Portal within the Automation Resource Group or using the Azure CLI
   1. If the portal is used use the portal UX to upload the Powershell runbook file located in the scripts/automation directory 

  example Azure Runbook name: 'rb-asb-firewall-automation-dev'

  The Azure CLI command for this action was causing errors at the time of writing this.  The following command allows for creating a PowerShell "shell" so that the Az PowerShell module can be used.  

  ```azurecli
  
    pwsh -command "Install-Module -Name Az.Automation; New-AzAutomationRunbook -Type 'PowerShell' -AutomationAccountName {automation account name} -Name {runbook name} -ResourceGroupName {automation resource group name};"

    az automation runbook replace-content --automation-account-name {automation account name} --resource-group {automation resource group name} --name {runbook name} --content @"{path to runbook file}"

  ```

5. Create Automation Account Schedule

  ```azurepowershell
    
    New-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $schedule_Name -StartTime $start_Time -ExpiryTime $end_Time -DayInterval 1 -ResourceGroupName $Resource_Group_Name_for_Automation

    $params = @{}
    $params.Add("resource_Group_Name_with_Firewall", "$Resource_Group_Name_with_Firewall")
    $params.Add("resource_Group_Name_for_Automation", "$Resource_Group_Name_for_Automation") 
    $params.Add("automation_Account_Name", "$Automation_Account_Name")  
    $params.Add("tenant_Id", "$tenant_Id")
    $params.Add("resource_Group_Name_with_Alerts", "$Resource_Group_Name_with_Alerts")
    $params.Add("subscription_Name", "$subscription_Name")
    $params.Add("vnet_Name", "$vnet_Name")
    $params.Add("firewall_Name", "$firewall_Name")
    $params.Add("pip_Name1", "$pip_Name1")
    $params.Add("pip_Name2", "$pip_Name2")
    $params.Add("pip_Name_Default", "$pip_Name_Default")
    $params.Add("managed_Identity_Name", "$managed_Identity_Name")
    $params.Add("environment", "$Environment")
    $params.Add("action", "$action")
    $params.Add("location", "$Location")

    Register-AzAutomationScheduledRunbook -Parameters $params -ResourceGroupName $Resource_Group_Name_for_Automation -AutomationAccountName $Automation_Account_Name -RunbookName $powerShell_Runbook_Name -ScheduleName $schedule_Name


  ```

6. LInk the Runbook to the schedules
 
### BASH Variables

The BASH variables are exported into environment variables.  

``` bash
export ASB_FW_Tenant_Id='' # Tenant Id for the onmicrosoft.com tenant
export ASB_FW_Subscription_Id='' # Suscription Id for Jofultz-Team
export ASB_FW_Resource_Group_Name_for_Automation='' # Resource Group that houses all the automation resources.
export ASB_FW_Resource_Group_Name_with_Firewall='' # Resource Group that houses the firewall to be automated.
export ASB_FW_Location='' # Location for resource creation
export ASB_FW_Automation_Account_Name='' # Name for automation account created
export ASB_FW_Sku='Basic' # Sku for the Automation Account
export ASB_FW_PowerShell_Runbook_Name='' # Powershell based runbook name.
export ASB_FW_PowerShell_Runbook_File_Name='' # Powershell based runbook file name.
export ASB_FW_Identity_Name='' # Managed Identity name.
export ASB_FW_PowerShell_Runbook_Description=''
export ASB_FW_PowerShell_Runbook_Output_Folder='.'
export ASB_FW_Environment=''
export ASB_FW_Base_Schedule_Name='asb-firewall-automation'

```

### Automated Scripts to Run
BEFORE continuing please make sure all requirements have been met in the section labeled [prerequisites]("#-prerequisites").

1. [Create Automation Infrastructure (BASH script)]("./scripts/automation/createautimationForFirewallCostOptimization.sh")
   - The [createAutomationForFirewallCostOptimization.sh]("./scripts/automation/createautimationForFirewallCostOptimization.sh") script "dot sources" the [firewallAutomationForCostOptimization.variables.sh]("./scripts/automation/cfirewallAutomationForCostOptimization.variables.sh").  This file must to be adjusted for the specifics of the execution.  Currently it is not populated save the default for Sku.  See ["BASH Variables for details"]("#-bash-variables").

## Detail of What is Happening in the Scripts

Below will detail what is being executed within the script files for further understanding.  This section is informational only.

### 1. Adjsut Variables for Current Values

The file [firewallAutomationForCostOptimization.variables.sh]("./scripts/automation/cfirewallAutomationForCostOptimization.variables.sh") must be adjusted to include relevant values.  

- ASB_FW_Tenant_Id=''
- ASB_FW_Subscription_Id=''
- ASB_FW_Resource_Group_Name_for_Automation=''
- ASB_FW_Resource_Group_Name_with_Firewall=''
- ASB_FW_Location='' 
- ASB_FW_Automation_Account_Name=''
- ASB_FW_Sku='Basic'
- ASB_FW_PowerShell_Runbook_Name=''
- ASB_FW_PowerShell_Runbook_File_Name=''
- ASB_FW_Identity_Name=''
- ASB_FW_PowerShell_Runbook_Description=''
- ASB_FW_PowerShell_Runbook_Output_Folder='.'
- ASB_FW_Environment=''
- ASB_FW_Base_Schedule_Name='asb-firewall-automation'

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
| ASB_FW_TenantId | 00000000-0000-0000-0000-000000000000 ||
| ASB_FW_SubscriptionId | 00000000-0000-0000-0000-000000000000 |  |
| ASB_FW_Sku | Basic |  |
| ASB_FW_Automation_Resource_Group_Name | rg-asb-firewall-automation |  |
| ASB_FW_Resource_Group_Core | rg-ngsa-asb-dev-hub |  |
| ASB_FW_Location | eastus |  |
| ASB_FW_Automation_Account_Name | aa-asb-firewall-automation |  |
| ASB_FW_PowerShell_Runbook_Name | rb-asb-firewall-automation |  |
| ASB_FW_PowerShell_Runbook_File_Name | firewallAutomationForCostOptimization.ps1 |  |
| ASB_FW_Identity_Name | mi-asb-firewall-automation |  |
| ASB_FW_PowerShell_Runbook_Description | This runbook automates the allocation and de-allocation of a firewall for the purposes of scheduling." | Description of Runbook |
| ASB_FW_PowerShell_Runbook_Output_Folder | . |  |
| ASB_FW_Environment | dev |  |
| ASB_FW_Base_Schedule_Name_Start | asb-fw-start- |  |
| ASB_FW_Base_Schedule_Name_Stop | asb-fw-stop- |  |
| AssigneeObjectId              | 00000000-0000-0000-0000-000000000000 | [Az Role Assignment Assignee-Object-Id](https://learn.microsoft.com/en-us/cli/azure/role/assignment?view=azure-cli-latest#az-role-assignment-create-optional-parameters)                                                                                                                                                                                                              |
| vnetName                      |           vnet-cetntral-hub          | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| firewallName                  |             fw-centralus             | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| pip_name1                     |          pip-fw-centralus-01         | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| pip_name2                     |          pip-fw-centralus-02         | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| pip_name_default              |       pip-fw-centralus-default       | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| UAMI                          |    mi-asb-firewall-automation-dev   | User-Assigned Managed Identity name.

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

### Associate Schedule with Runbook

```powershell
Write-Host "Registering an Azure Automation Schedule to a Automation Runbook..."
  $error.Clear()

  $params = @{}
  $params.Add("resource_Group_Name_with_Firewall", "$Resource_Group_Name_with_Firewall")
  $params.Add("resource_Group_Name_for_Automation", "$Resource_Group_Name_for_Automation")
  $params.Add("automation_Account_Name", "$Automation_Account_Name")
  $params.Add("subscription_Name","$subscription_Name")
  $params.Add("vnet_Name", "$vnet_Name")
  $params.Add("firewall_Name", "$firewall_Name")
  $params.Add("pip_Name1", "$pip_Name_1")
  $params.Add("pip_Name2", "$pip_Name_2")
  $params.Add("pip_Name_Default", "$pip_Name_Default")
  $params.Add("managed_Identity_Name", "$managed_Identity_Name")
  $params.Add("action", "$action")

  Register-AzAutomationScheduledRunbook -Parameters $params -ResourceGroupName $Resource_Group_Name_for_Automation -AutomationAccountName $Automation_Account_Name -RunbookName $powerShell_Runbook_Name -ScheduleName $schedule_Name
  Write-Host "Completed registering an Azure Automation Schedule to a Automation Runbook."
```

### Reference

- [Microsoft - FAQ - How can I stop and start azure firewalls](https://learn.microsoft.com/en-us/azure/firewall/firewall-faq#how-can-i-stop-and-start-azure-firewall)
- [WCNP - Automated FW malloc & free](https://github.com/retaildevcrews/wcnp/issues/1003)
- [WCNP - Migrate Infrastructure](https://github.com/retaildevcrews/wcnp/issues/815)
- [Microsoft - Automation Services - Azure Automation](https://learn.microsoft.com/en-us/azure/automation/automation-services#azure-automation)
- [Microsoft - Create Automation PowerShell RunBook using managed identity](https://learn.microsoft.com/en-us/azure/automation/learn/powershell-runbook-managed-identity)
