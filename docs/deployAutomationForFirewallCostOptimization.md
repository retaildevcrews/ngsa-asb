# Web Application Firewall (WAF) Allocation/De-Allocation Automation

Azure Firewall has [costs (Azure Firewall pricing link)](https://azure.microsoft.com/en-gb/pricing/details/azure-firewall/#pricing) associated with it which can be optimized by allocating and de-allocating the firewall when appropriate.  Below describes the mechanism to implement an Azure Automation Runbook that will allocate and de-allocate the firewall on a schedule as well as enable and disable the alerts associated with this activity to minimize nonessential systems communications.

## Prerequisites

Before proceeding verify  the environment is configured correct to execute the commands necessary below

- Azure CLI 2.0 or greater [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

- Azure CLI Extension for Automation [Install Azure CLI Extensions](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-list)

- Azure CLI Extension for Monitor [Install Azure CLI Extensions](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-list)

- Azure Powershell modules for Linux [Install Modules](/allocationAutomationForFirewall.md#Install-Powershell-Modules)

### Set Subscription & Tenant

Replace the $1 with subscription name.

``` bash
echo "Setting subscription to $1 and Tenant Id to $2..."
az account set --subscription $1 --TenantId $2
echo "Completed setting Subscription to $1 and Tenant Id to $2."
```

### Install Powershell Modules

The following command should be executed from the Codespaces environment to ensure the modules are installed.  These commands can be executed from an authenticated Azure Powershell terminal.

#### PowerShell Modules

```PowerShell
Install-Module -Name Az.Automation -Force
Import-Module -Name Az.Automation -Force

Install-Module -Name Az.Monitor -Force
Import-Module -Name Az.Monitor -Force
```

### Install Azure CLI Assets

Follow the steps below to assure the prerequisites are installed and up-to-date and all necessary extensions are installed.

#### Azure CLI Upgrade

```bash
# check the version of the Azure CLI installed.  
az version
# if < than 2.4.0 
echo "Upgrading to latest version of Azure CLI..."
az upgrade --output none 
echo "Completed updating "
echo "Azure CLI version: $(az --version | grep azure-cli | awk '{print $2}""
```

#### Azure CLI Extensions

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

## Infrastructure & Assets Creation List

The following infrastructure assets should be established in the subscription with the Azure Firewall(s) to be managed once all aspects of this document are fulfilled.  Though six (6) items are listed, technically one (1) item is an import of content to the body of the Azure Automation Runbook so this item will not show up in the portal without deeper investigation.  

|     | Resource                                  |                                                                                       Links                                                                                      | Description                                                                                                                                                                 |
| :-: | :---------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|  1. | Resource Group                            |                                                 [link](https://learn.microsoft.com/en-us/cli/azure/manage-azure-groups-azure-cli)                                                | Create "sibling" resource group in subscription for Azure Automation infrastructure.                                                                                        |
|  2. | Automation Account                        |                     [link](https://learn.microsoft.com/en-us/azure/templates/microsoft.automation/automationaccounts?pivots=deployment-language-arm-template)                    | Create an Automation Account that will execute the automation.                                                                                                              |
|  3. | User-Assigned Managed Identity            | [link](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-manage-user-assigned-managed-identities?pivots=identity-mi-methods-azcli) | Create an identity for the Automation Account.                                                                                                                              |
|  4. | Automation Runbook with Powershell        |                                      [link](https://learn.microsoft.com/en-us/azure/automation/automation-runbook-types#powershell-runbooks)                                     | Create a Runbook of type Powershell.                                                                                                                                        |
|  5. | Powershell Content in Runbook             |                               [link](https://learn.microsoft.com/en-us/powershell/module/az.automation/import-azautomationrunbook?view=azps-8.3.0)                               | Upload [pre-defined Powershell content](../automation/FirewallToggle.ps1) into the Runbook body.                                                                            |
|  6. | Automation Schedule(s) _using Powershell_ |                               [link](https://learn.microsoft.com/en-us/powershell/module/az.automation/import-azautomationrunbook?view=azps-8.3.0)                               | Create the schedules that will execute the Firewall automation.  These had to be created using Powershell instead of the Azure CLI.  No equivalent behavior has been found. |

### Parameters Needed to Proceed

| Parameter Name                |             Example Value            | Rules for Naming                                                                                                                                                                                                                                                                                                                                                            |
| ----------------------------- | :----------------------------------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AutomationResourceGroupName   |        rg-ngsa-automation-dev        | prefix with 'rg-' </br> suffix with environment abbreviation '-dev'                                                                                                                                                                                                                                                                                                           |
| Location                      |                eastus                | [Azure CLI command to get total list of location names](https://learn.microsoft.com/en-us/cli/azure/account?view=azure-cli-latest#az-account-list-locations)                                                                                                                                                                                                                |
| AutomationAccountName         |    aa-ngsa-firewall-automation-dev   | 1. 6-50 Alphanumerics and hyphens.</br>  2. Start with letter and end with alphanumeric.6-50. </br>  3. Alphanumerics and hyphens.</br>  4. Start with letter and end with alphanumeric.</br>[Link to documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftautomation)|
| Sku                           |                 Basic                | Set this to 'Basic'                                                                                                                                                                                                                                                                                                                                                         |
| AssigneeObjectId              | 00000000-0000-0000-0000-000000000000 | [Az Role Assignment Assignee-Object-Id](https://learn.microsoft.com/en-us/cli/azure/role/assignment?view=azure-cli-latest#az-role-assignment-create-optional-parameters)                                                                                                                                                                                                    |
| Subscription                  |             jofultz-team             | The subscription should be set to the name of the subscription with the Azure Firewall to be automated.                                                                                                                                                                                                                                                                     |
| ResourceGroupNameWithFirewall |           ngsa-asb-dev-hub           | The NGSA Azure Firewall is located in the resource group suffixed with '-hub'.                                                                                                                                                                                                                                                                                              |
| vnetName                      |           vnet-cetntral-hub          | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| firewallName                  |             fw-centralus             | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| pip_name1                     |          pip-fw-centralus-01         | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| pip_name2                     |          pip-fw-centralus-02         | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| pip_name_default              |       pip-fw-centralus-default       | Found in the portal.                                                                                                                                                                                                                                                                                                                                                        |
| UAMI                          |    mi-ngsa-firewall-automation-dev   | User-Assigned Managed Identity name.                                                                                                                                                                                                                                                                                                                                        |

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
    Register-AzAutomationScheduledRunbook -AutomationAccountName $Env:AutomationAccountName -RunbookName $Env:PowerShellRunbookName -ScheduleName "$Env:BaseScheduleNameStart$Env:Asb_Environment" -ResourceGroupName $Env:AutomationResourceGroupName -Parameters @{"resourceGroupName"="$Env:AutomationResourceGroupName";"automationAccount"="$Env:AutomationAccountName";"subscriptionName"="$Env:Subscription";"vnetName"="vnet-cetntral-hub";"fw_name"="fw-centralus";"pip_name1"="pip-fw-centralus-01";"pip_name2"="pip-fw-centralus-02";"pip_name_default"="pip-fw-centralus-default";"UAMI"="$Env:IdentityName";"update"="start"}

    Register-AzAutomationScheduledRunbook -AutomationAccountName $Env:AutomationAccountName -RunbookName $Env:PowerShellRunbookName -ScheduleName "$Env:BaseScheduleNameStop$Env:Asb_Environment" -ResourceGroupName $Env:AutomationResourceGroupName -Parameters @{"resourceGroupName"="$Env:AutomationResourceGroupName";"automationAccount"="$Env:AutomationAccountName";"subscriptionName"="$Env:Subscription";"vnetName"="vnet-cetntral-hub";"fw_name"="fw-centralus";"pip_name1"="pip-fw-centralus-01";"pip_name2"="pip-fw-centralus-02";"pip_name_default"="pip-fw-centralus-default";"UAMI"="$Env:IdentityName";"update"="stop"}
```

### PowerShell Artifact

```powershell
  Param(
      [Parameter(Mandatory)]
      [String]$resourceGroupName,

      [Parameter(Mandatory)]
      [String]$automationAccount,

      [Parameter(Mandatory)]
      [String]$subscriptionName,

      [Parameter(Mandatory)]
      [String]$vnetName,
      
      [Parameter(Mandatory)]
      [String]$fw_name,
      
      [Parameter(Mandatory)]
      [String]$pip_name1,
      
      [Parameter(Mandatory)]
      [String]$pip_name2,
      
      [Parameter(Mandatory)]
      [String]$pip_name_default,
      
      [Parameter(Mandatory = $True)]
      [String]$UAMI,
      
      [Parameter(Mandatory = $True)]
      [String]$update
  )

  # Ensures you do not inherit an AzContext in your runbook
  Write-Output "Disabling AzContext Autosave"
  Disable-AzContextAutosave -Scope Process | Out-Null

  # Connect using a Managed Service Identity
  Write-Output "Using system-assigned managed identity"

  try {
      $AzureContext = (Connect-AzAccount -Identity).context
  }
  catch {
      Write-Output "There is no system-assigned user identity. Aborting."; 
      exit
  }

  # set and store context
  $AzureContext = Set-AzContext -SubscriptionName $subscriptionName -DefaultProfile $AzureContext
  Write-Output "Using user-assigned managed identity"

  # Connects using the Managed Service Identity of the named user-assigned managed identity
  $identity = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $UAMI -DefaultProfile $AzureContext

  # validates assignment only, not perms
  if ((Get-AzAutomationAccount -ResourceGroupName $resourceGroupName -Name $automationAccount -DefaultProfile $AzureContext).Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId)) {
      $AzureContext = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context

      # set and store context
      $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
  }
  else {
      Write-Output "Invalid or unassigned user-assigned managed identity"
      exit
  }


  function Stop-Firewall {

      param (
          [parameter(Mandatory = $True)]
          [String]$fw_name,
          [Parameter(Mandatory = $True)]
          [String]$resourceGroupName
      )

      Write-Host "De-allocating Firewall....."

      $azfw = Get-AzFirewall -Name $fw_name -ResourceGroupName $resourceGroupName
      $azfw.Deallocate()

      Set-AzFirewall -AzureFirewall $azfw    
  }

  function Restart-Firewall {

      param (
          [parameter(Mandatory = $True)]
          [String]$resourceGroupName,
          [Parameter(Mandatory = $True)]
          [String]$fw_name, 
          [parameter(Mandatory = $True)]
          [String]$vnetName,
          [Parameter(Mandatory = $True)]
          [String]$pip_name1, 
          [parameter(Mandatory = $True)]
          [String]$pip_name2,
          [Parameter(Mandatory = $True)]
          [String]$pip_name_default
      )

      Write-Host "Allocating Firewall....."

      $azfw = Get-AzFirewall -Name $fw_name -ResourceGroupName $resourceGroupName
      $vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName
      $publicip1 = Get-AzPublicIpAddress -Name $pip_name1 -ResourceGroupName $resourceGroupName
      $publicip2 = Get-AzPublicIpAddress -Name $pip_name2 -ResourceGroupName $resourceGroupName
      $publicip_default = Get-AzPublicIpAddress -Name $pip_name_default -ResourceGroupName $resourceGroupName
      $azfw.Allocate($vnet, @($publicip_default, $publicip1, $publicip2))

      Set-AzFirewall -AzureFirewall $azfw
  }
  function Update-Metric-Alert {

      param (
          [parameter(Mandatory = $True)]
          [String]$resourceGroupName,
          
          [Parameter(Mandatory = $True)]
          [String]$ruleName, 

          [Parameter(Mandatory = $True)]
          [Switch]$enableRule
      )
    

      Get-AzMetricAlertRuleV2 -ResourceGroupName $resourceGroupName  -Name $ruleName | Add-AzMetricAlertRuleV2 $enableRule
  }

  function Update-Log-Alert {

      param (
          [parameter(Mandatory = $True)]
          [String]$resourceGroupName,
          
          [Parameter(Mandatory = $True)]
          [String]$ruleName, 

          [Parameter(Mandatory = $True)]
          [Switch]$enableRule
      )

      if($enableRule) {
          Enable-AzActivityLogAlert -Name $ruleName -ResourceGroupName $resourceGroupName
      }
      else {
          Disable-AzActivityLogAlert -Name $ruleName -ResourceGroupName $resourceGroupName
      }
      

  }

  function Disable-Metric-Alerts {
      
      param (
          [parameter(Mandatory = $True)]
          [String]$resourceGroupName,
          
          [Parameter(Mandatory = $True)]
          [String]$ruleName
      )


      Update-Metric-Alert $resourceGroupName "asb-pre-centralus-AppEndpointDown" -DisableRule
      Update-Metric-Alert $resourceGroupName "asb-pre-eastus-AppEndpointDown" -DisableRule
      Update-Metric-Alert $resourceGroupName "asb-pre-westus-AppEndpointDown" -DisableRule

  }
  function Enable-Metric-Alerts {

      param (
          [parameter(Mandatory = $True)]
          [String]$resourceGroupName,
          
          [Parameter(Mandatory = $True)]
          [String]$ruleName
      )
      param (
          [parameter(Mandatory = $True)]
          [String]$resourceGroupName,
          
          [Parameter(Mandatory = $True)]
          [String]$ruleName
      )

      Update-Metric-Alert $resourceGroupName "asb-pre-centralus-AppEndpointDown" -EnableRule
      Update-Metric-Alert $resourceGroupName "asb-pre-eastus-AppEndpointDown" -EnableRule
      Update-Metric-Alert $resourceGroupName "asb-pre-westus-AppEndpointDown" -EnableRule
  }

  function Disable-Log-Alerts {
      
      param (
          [parameter(Mandatory = $True)]
          [String]$resourceGroupName)


      Update-Log-Alert $resourceGroupName "asb-dev-centralus-AppEndpointDown" -DisableRule
      Update-Log-Alert $resourceGroupName "asb-dev-eastus-AppEndpointDown" -DisableRule
      Update-Log-Alert $resourceGroupName "asb-dev-westus-AppEndpointDown" -DisableRule

  }

  function Enable-Log-Alerts {
    param (
          [parameter(Mandatory = $True)]
          [String]$resourceGroupName)
      Update-Log-Alert $resourceGroupName "asb-dev-centralus-AppEndpointDown" -EnableRule
      Update-Log-Alert $resourceGroupName "asb-dev-eastus-AppEndpointDown" -EnableRule
      Update-Log-Alert $resourceGroupName "asb-dev-westus-AppEndpointDown" -EnableRule
  }

  if ($update -eq "Stop") {
      Stop-Firewall $fw_name $resourceGroupName
      Disable-Metric-Alerts $resourceGroupName
      Disable-Log-Alerts $resourceGroupName
  }
  elseif ($update -eq "Start") {
      Restart-Firewall $resourceGroupName $fw_name $vnetName $pip_name1 $pip_name2 $pip_name_default
      Enable-Metric-Alerts $resourceGroupName
      Enable-Log-Alerts $resourceGroupName
  }

  Write-Output "Firewall Status Updated" 
```

### Reference

- [Microsoft - FAQ - How can I stop and start azure firewalls](https://learn.microsoft.com/en-us/azure/firewall/firewall-faq#how-can-i-stop-and-start-azure-firewall)
- [WCNP - Automated FW malloc & free](https://github.com/retaildevcrews/wcnp/issues/1003)
- [WCNP - Migrate Infrastructure](https://github.com/retaildevcrews/wcnp/issues/815)
- [Microsoft - Automation Services - Azure Automation](https://learn.microsoft.com/en-us/azure/automation/automation-services#azure-automation)
- [Microsoft - Create Automation PowerShell RunBook using managed identity](https://learn.microsoft.com/en-us/azure/automation/learn/powershell-runbook-managed-identity)
