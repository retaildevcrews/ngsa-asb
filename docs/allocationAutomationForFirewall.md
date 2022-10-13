# Web Application Firewall (WAF) Allocation/De-Allocation Automation

Azure Firewall has [costs (Azure Firewall Pricing Link)](https://azure.microsoft.com/en-gb/pricing/details/azure-firewall/#pricing) associated with it, that when appropriate, can be optimized by allocating and de-allocating the firewall when appropriate.  Below describes the mechanism to implement an Azure Automation runbook that will allocate and de-allocate the firewall on a schedule as well as enable and disable the alerts associated.

## Prerequisites

- Azure CLI 2.0 or greater [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

- Azure CLI Extension for Automation [Install Azure CLI Extensions](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-list)

## Infrastructure & Assets to Create

The following infrastructure assets should be established in the subscription with the Azure Firewall(s) to be managed.

- [Create a 'sibling' Azure Resource Group](https://learn.microsoft.com/en-us/cli/azure/manage-azure-groups-azure-cli) for Azure Automation Infrastructure
  - [Create an Azure Automation Account](https://learn.microsoft.com/en-us/azure/templates/microsoft.automation/automationaccounts?pivots=deployment-language-arm-template).
  - [User-Assigned Managed Identity](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-manage-user-assigned-managed-identities?pivots=identity-mi-methods-azcli) configured for Firewall access
  - [Create an Azure Automation Runbook](https://learn.microsoft.com/en-us/azure/automation/automation-runbook-types#powershell-runbooks)
  - [Import PowerShell](https://learn.microsoft.com/en-us/powershell/module/az.automation/import-azautomationrunbook?view=azps-8.3.0) artifact into the Azure Automation Runbook replace content to assign the Powershell content
  - [Create an Automation Schedule using PowerShell](https://learn.microsoft.com/en-us/powershell/module/az.automation/import-azautomationrunbook?view=azps-8.3.0)

### Prerequisites Script

Follow the steps below to assure the prerequisites are installed and up-to-date.

``` bash
  # check the version of the Azure CLI installed.  
  az version
  # if < than 2.4.0 
  echo "Upgrading to latest version of Azure CLI..."
  az upgrade --output none 
  echo "Completed updating Azure CLI version: $(az --version | grep azure-cli | awk '{print $2}')"
```

### Parameters Needed to Proceed

| Parameter Name | Example Value | Rules for Naming |
|--------------|:-----:|-----------:|
| AutomationResourceGroupName | rg-ngsa-automation-dev | |
| Location | eastus | |
| AutomationAccountName | ngsaAutomation | [6-50	Alphanumerics and hyphens.  Start with letter and end with alphanumeric.6-50.  Alphanumerics and hyphens.  Start with letter and end with alphanumeric.](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftautomation) |
| Sku | Basic | |
| Assignee | 00000000-0000-0000-0000-000000000000  | [Az Role Assignment Assignee](https://learn.microsoft.com/en-us/cli/azure/role/assignment?view=azure-cli-latest#az-role-assignment-create-optional-parameters) |
| Subscription | 00000000-0000-0000-0000-000000000000  | |
|ResourceGroupNameWithFirewall|||
|vnetName|||
|firewallName|||
|pip_name1|||
|pip_name2|||
|pip_name_default|||
|UAMI| User-Assigned Managed Identity ||
|update| Start, Stop ||

### Install Azure CLI Extension

``` bash
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
```

### Create Resource Group

  ``` bash
  #Check if automation resource group exists, and create it if it does not.
  if [ $(az group exists --name $AutomationResourceGroup) = false ]; then
    az group create 
    --name $AutomationResourceGroup 
    --location $Location
  fi
  ```

### Create Azure Automation Account

  ``` bash
    echo "Creating Azure Automation Account $AutomationAccountName in Resource Group $AutomationResourceGroupName..."
    if [[ $(az automation account list --resource-group $AutomationResourceGroupName --query "[?name=='$AutomationAccountName'] | length(@)") > 0 ]];
    then
      echo "$AutomationAccountName exists, please review, and choose a different name if appropriate."

    else
      echo "Creating Azure Automation Account $AutomationAccountName..."
      
      az automation account create --automation-account-name $AutomationAccountName --location $Location --sku $Sku --resource-group $AutomationResourceGroupName

      echo "Complated creating Azure Automation Account $AutomationAccountName."
  fi

  echo "Completed creating Azure Automation Account $AutomationAccountName in Resource Group $AutomationResourceGroupName."
```

### Create User-Assigned Managed Identity

``` bash
  echo "Creating User-Assigned Managed Identity $IdentityName..."
  az identity create --resource-group $AutomationResourceGroup --name $IdentityName
  echo "Completed created User-Assigned Managed Identity $IdentityName in $AutomationResourceGroup."   
```

### Assign Role to User-Assigned Managed Identity

``` bash
  echo "Assigning User-Assigned Managed Identity $IdentityName to $Subscription..."
  az role assignment create --assignee "$IdentityName" --role "Microsoft.Network/azureFirewalls" --subscription "$Subscription"
  echo "Completed Assigning User-Assigned Managed Identity $IdentityName to $Subscription."

```

### Assign User-Assigned Managed Identity to Automation Account

``` bash
  echo "Assigning User-Assigned Managed Identity $IdentityName to $AutomationAccountName in $AutomationResourceGroup..."
  az automation account identity assign --resource-group $AutomationResourceGroup --name $AutomationAccountName --identity $IdentityName
  echo "Completed assigning User-Assigned Managed Identity $IdentityName to $AutomationAccountName in $AutomationResourceGroup."
```

### Create Automation Powershell Runbook

``` bash
  if [[ $(az automation runbook list --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --query "[?name=='$PowerShellRunbookName'] | length(@)") > 0 ]]; then
        echo "$PowerShellRunbookName exists, please review, and choose a different name if appropriate."
    else
        echo "Creating PowerShell Runbook $PowerShellRunbookName in $AutomationResourceGroup for $AutomationAccountName..."
        az automation runbook create --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --name $PowerShellRunbookName --runbook-type PowerShell --description $PowerShellRunbookDescription --log-progress --log-debug --log-error --log-output --output-folder $PowerShellRunbookOutputFolder
        echo "Completed creating PowerShell Runbook $PowerShellRunbookName in $AutomationResourceGroup for $AutomationAccountName."
    fi
```

### Publish Runbook

``` bash
  echo "Uploading Runbook Content $RunbookName to $AutomationAccountName in $AutomationResourceGroup..."
  az automation runbook publish --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --name $RunbookName --type PowerShell --log-progress --description $RunbookDescription --runbook-content   az automation runbook publish --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --name $RunbookName --type PowerShell --log-progress --description $RunbookDescription --runbook-content "./FirewallToggle.ps1"
  echo "Completed uploading Runbook Content $RunbookName to $AutomationAccountName in $AutomationResourceGroup"
```

### Create Schedule (PowerShell)

``` azurepowershell

  $StartTime = Get-Date "13:00:00"
  $EndTime = $StartTime.AddYears(3)

  New-AzAutomationSchedule 
  -AutomationAccountName $AutomationAccountName 
  -Name $ScheduleName 
  -StartTime $StartTime 
  -ExpiryTime $EndTime 
  -DayInterval 1 
  -ResourceGroupName $AutomationResourceGroup
```

### Associate Schedule with Runbook

``` bash
  echo "Creating schedule for runbook $1 in $AutomationResourceGroup for $AutomationAccountName..."
  az automation schedule create --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --name $ScheduleName --description $ScheduleDescription --start-time $ScheduleStartTime --expiry-time $ScheduleExpiryTime --frequency $ScheduleFrequency --interval $ScheduleInterval --time-zone $ScheduleTimeZone --advanced-schedule $ScheduleAdvancedSchedule
  echo "Completed creating schedule for runbook $1 in $AutomationResourceGroup for $AutomationAccountName."
```

### PowerShell Artifact

``` powershell
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

    Write-Host "Deallocating Firewall....."

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

if ($update -eq "Stop") {
    Stop-Firewall $fw_name $resourceGroupName
}
elseif ($update -eq "Start") {
    Restart-Firewall $resourceGroupName $fw_name $vnetName $pip_name1 $pip_name2 $pip_name_default
}

Write-Output "Firewall Status Updated" 
```

### Reference

- [Microsoft - FAQ - How can I stop and start azure firewalls](https://learn.microsoft.com/en-us/azure/firewall/firewall-faq#how-can-i-stop-and-start-azure-firewall)
- [WCNP - Automated FW malloc & free](https://github.com/retaildevcrews/wcnp/issues/1003)
- [WCNP - Migrate Infrastructure](https://github.com/retaildevcrews/wcnp/issues/815)
- [Microsoft - Automation Services - Azure Automation](https://learn.microsoft.com/en-us/azure/automation/automation-services#azure-automation)
- [Microsoft - Create Automation PowerShell RunBook using managed identity](https://learn.microsoft.com/en-us/azure/automation/learn/powershell-runbook-managed-identity)
