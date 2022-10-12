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
  az upgrade
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
  # configure Azure CLI to allow for dynamic installation of 
  # extensions without prompts
  az config set extension.use_dynamic_install=yes_without_prompt
  
  # Install or update Azure CLI automation extension
  if [[ $(az extension list --query "[?name=='automation']") = false ]];
  then
    az extension add --name automation
  else
    az extension update --name automation
  fi

  # configure Azure CLI to disallow dynamic installation of
  # extensions without prompts
  az config set extension.use_dynamic_install=yes_prompt
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
  # Check if account exists, if so ask to change name, else create  
  if [[ $(az automation account list 
  --resource-group $AutomationResourceGroup 
  --query "[?name=='$AutomationAccountName'] | length(@)") > 0 ]]; then
    echo "$AutomationResourceGroup exists, please review, "
    echo " and choose a different name if appropriate."

  else
    echo "Creating Resource Group $AutomationResourceGroup..."

    az automation account create 
    --automation-account-name $AutomationAccountName 
    --location $Location 
    --sku $Sku 
    --resource-group $AutomationResourceGroup
fi
```

### Create User-Assigned Managed Identity

``` bash
  az identity create 
  --resource-group $AutomationResourceGroup 
  --name $IdentityName    
```

### Assign Role to User-Assigned Managed Identity

``` bash
  az role assignment create 
  --assignee "$Assignee" 
  --role "Microsoft.Network/azureFirewalls" 
  --subscription "$Subscription"

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

``` azurepowershell

  $automationAccountName = $AutomationAccountName
  $runbookName = "Firewall-Automation"
  $scheduleName = "WCNP-DailySchedule"

  $params = @{"resourceGroupName"=$ResourceGroupNameWithFirewall;
  "vnetName"=$vnetName;
  "fw_name"=$fireWallName;
  "pip_name1"=$pip_name1;
  "pip_name2"=$pip_name2;
  "pip_name_default"=$pip_name_default;
  "UAMI"=$UAMI;
  "update"=$upate;}

  Register-AzAutomationScheduledRunbook 
  -AutomationAccountName $automationAccountName
  -Name $runbookName 
  -ScheduleName $scheduleName 
  -Parameters $params 
  -ResourceGroupName $AutomationResourceGroup
```

### Remove Firewall "affected" Alerts

``` bash

```

### Restore Firewall "affected" Alerts

``` bash

```

### PowerShell Artifact

``` powershell
    Param(
        [Parameter(Mandatory)]
        [String]$resourceGroupName,
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
        [Parameter(Mandatory=$True)]
        [String]$UAMI,
        [Parameter(Mandatory=$True)]
        [String]$update
    )

    $automationAccount = "rg-nu-ngsa-dev-automation"

    # Ensures you do not inherit an AzContext in your runbook
    Disable-AzContextAutosave -Scope Process | Out-Null

    # Connect using a Managed Service Identity
    Write-Output "Using system-assigned managed identity"

    try {
            $AzureContext = (Connect-AzAccount -Identity).context
        }
    catch{
            Write-Output "There is no system-assigned user identity. Aborting."; 
            exit
        }

    # set and store context
    $AzureContext = Set-AzContext -SubscriptionName "jofultz-rdc" `
        -DefaultProfile $AzureContext

    Write-Output "Using user-assigned managed identity"

    # Connects using the Managed Service Identity of the named user-assigned managed identity
    $identity = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName `
      -Name $UAMI -DefaultProfile $AzureContext

    # validates assignment only, not perms
    if ((Get-AzAutomationAccount -ResourceGroupName $resourceGroupName `
        -Name $automationAccount `
        -DefaultProfile $AzureContext).Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId))
      {
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
            [parameter(Mandatory=$True)]
            [String]$fw_name,
            [Parameter(Mandatory=$True)]
            [String]$resourceGroupName
        )

        Write-Host "Deallocating Firewall....."

        $azfw = Get-AzFirewall -Name $fw_name -ResourceGroupName $resourceGroupName
        $azfw.Deallocate()

        Set-AzFirewall -AzureFirewall $azfw    
    }

    function Restart-Firewall {

        param (
            [parameter(Mandatory=$True)]
            [String]$resourceGroupName,
            [Parameter(Mandatory=$True)]
            [String]$fw_name, 
            [parameter(Mandatory=$True)]
            [String]$vnetName,
            [Parameter(Mandatory=$True)]
            [String]$pip_name1, 
            [parameter(Mandatory=$True)]
            [String]$pip_name2,
            [Parameter(Mandatory=$True)]
            [String]$pip_name_default
        )

        Write-Host "Allocating Firewall....."

        $azfw = Get-AzFirewall -Name $fw_name -ResourceGroupName $resourceGroupName
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName
        $publicip1 = Get-AzPublicIpAddress -Name $pip_name1 -ResourceGroupName $resourceGroupName
        $publicip2 = Get-AzPublicIpAddress -Name $pip_name2 -ResourceGroupName $resourceGroupName
        $publicip_default = Get-AzPublicIpAddress -Name $pip_name_default -ResourceGroupName $resourceGroupName
        $azfw.Allocate($vnet,@($publicip_default,$publicip1,$publicip2))

        Set-AzFirewall -AzureFirewall $azfw
    }


    if ($update -eq "Stop") {
        Stop-Firewall $fw_name $resourceGroupName
    }
    elseif($update -eq "Start") {
        Restart-Firewall $resourceGroupName $fw_name $vnetName $pip_name1 $pip_name2 $pip_name_default
    }

    Write-Output "Firewall Status Updated" 

    # ToDo: Remove and add alerts as appropriate
```

### Reference

- [Microsoft - FAQ - How can I stop and start azure firewalls](https://learn.microsoft.com/en-us/azure/firewall/firewall-faq#how-can-i-stop-and-start-azure-firewall)
- [WCNP - Automated FW malloc & free](https://github.com/retaildevcrews/wcnp/issues/1003)
- [WCNP - Migrate Infrastructure](https://github.com/retaildevcrews/wcnp/issues/815)
- [Microsoft - Automation Services - Azure Automation](https://learn.microsoft.com/en-us/azure/automation/automation-services#azure-automation)
- [Microsoft - Create Automation PowerShell RunBook using managed identity](https://learn.microsoft.com/en-us/azure/automation/learn/powershell-runbook-managed-identity)
