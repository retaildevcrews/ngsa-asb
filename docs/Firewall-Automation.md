# Web Application Firewall (WAF) Allocation/De-Allocation Automation

Azure Firewall has [costs (Azure Firewall pricing link)](https://azure.microsoft.com/en-gb/pricing/details/azure-firewall/#pricing) associated with it which can be optimized by allocating and de-allocating the firewall when appropriate.  Below describes the mechanism to implement an Azure Automation Runbook that will allocate and de-allocate the firewall on a schedule as well as enable and disable the alerts associated with this activity to minimize nonessential systems communications.

## Before Beginning

### Prerequisites

Before proceeding verify the environment is configured correct to execute the commands necessary below

- Azure CLI 2.0 or greater [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

- Azure CLI Extension for Automation [Install Azure CLI Extensions](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-list)

- Azure CLI Extension for Monitor [Install Azure CLI Extensions](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-list)

- _Azure Powershell modules for Linux_ [Install Modules](/allocationAutomationForFirewall.md#Install-Powershell-Modules)

_The Azure CLI Automation extension is in an experimental stage.  Currently it does not implement all functionality needed.  As a result the the Az Module, specifically for automation, monitoring,  and authentication can be used at the time of writing._

- [_Azure CLI Extension - Automation_](https://github.com/Azure/azure-cli-extensions/tree/main/src/automation)
- [Azure PowerShell Az Modules](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-9.0.0)

### Parameters Needed to Proceed

#### Parameters for Bash Execution

| Parameter Name                        |                                             Example Value                                             | Script Needed For |
| ------------------------------------- | :---------------------------------------------------------------------------------------------------: | ----------------- |
| ASB_FW_TenantId                       |                                  00000000-0000-0000-0000-000000000000                                 | bash              |
| ASB_FW_SubscriptionId                 |                                  00000000-0000-0000-0000-000000000000                                 | bash              |
| ASB_FW_Sku                            |                                                 Basic                                                 | bash              |
| ASB_FW_Location                       |                                                 eastus                                                | bash              |
| ASB_FW_PowerShell_Runbook_File_Name   |                                    Firewall-Automation-Runbook.ps1                                    | PowerShell        |
| ASB_FW_PowerShell_Runbook_Description | This runbook automates the allocation and de-allocation of a firewall for the purposes of scheduling. | bash              |
| ASB_FW_Environment                    |                                                  dev                                                  | bash              |
| firewallName                          |                                              fw-centralus                                             | bash              |

#### Parameters for PowerShell Execution

| Parameter Name                     |             Example Value            | Script Needed For |
| ---------------------------------- | :----------------------------------: | ----------------- |
| Tenant_Id                          | 00000000-0000-0000-0000-000000000000 | PowerShell        |
| Subscription_Name                  |                                      | PowerShell        |
| Subscription_Id                    | 00000000-0000-0000-0000-000000000000 | PowerShell        |
| Resource_Group_Name_for_Automation |  rg-ngsa-asb-firewall-automation-dev | PowerShell        |
| Resource_Group_Name_with_Firewall  |          rg-ngsa-asb-dev-hub         | PowerShell        |
| Resource_Group_Name_with_Alerts    |            rg-ngsa-asb-dev           | PowerShell        |
| Location                           |                westus                | PowerShell        |
| Automation_Account_Name            |  aa-ngsa-asb-firewall-automation-dev | PowerShell        |
| Sku                                |                 Basic                | PowerShell        |
| PowerShell_Runbook_Name            |  rb-ngsa-asb=firewall-automation-dev | PowerShell        |
| Vnet_Name                          |            vnet-eastus-hub           | PowerShell        |
| Firewall_Name                      |               fw-eastus              | PowerShell        |
| PIP_Name1                          |           pip-fw-eastus-01           | PowerShell        |
| PIP_Name2                          |           pip-fw-eastus-02           | PowerShell        |
| PIP_Name_Default                   |         pip-fw-eastus-default        | PowerShell        |
| Managed_Identity_Name              |  mi-ngsa-asb-firewall-automation-dev | PowerShell        |
| Base_Schedule_Name                 |  as-ngsa-asb-firewall-automation-dev | PowerShell        |
| Environment                        |                  dev                 | PowerShell        |

### Infrastructure & Assets Creation List

The following infrastructure assets should be established in the subscription with the Azure Firewall(s) to be managed once all aspects of this document are fulfilled.  Though six (6) items are listed, technically one (1) item is an import of content to the body of the Azure Automation Runbook so this item will not show up in the portal without deeper investigation.  

|     | Resource                                  |                                                                                       Links                                                                                      | Description                                                                                                                                                                 |   |
| :-: | :---------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | - |
|  1. | Resource Group                            |                                                 [link](https://learn.microsoft.com/en-us/cli/azure/manage-azure-groups-azure-cli)                                                | Create "sibling" resource group in subscription for Azure Automation infrastructure.                                                                                        |   |
|  2. | Automation Account                        |                     [link](https://learn.microsoft.com/en-us/azure/templates/microsoft.automation/automationaccounts?pivots=deployment-language-arm-template)                    | Create an Automation Account that will execute the automation.                                                                                                              |   |
|  3. | User-Assigned Managed Identity            | [link](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-manage-user-assigned-managed-identities?pivots=identity-mi-methods-azcli) | Create an identity for the Automation Account.                                                                                                                              |   |
|  4. | Automation Runbook with Powershell        |                                      [link](https://learn.microsoft.com/en-us/azure/automation/automation-runbook-types#powershell-runbooks)                                     | Create a Runbook of type Powershell.                                                                                                                                        |   |
|  5. | Powershell Content in Runbook             |                               [link](https://learn.microsoft.com/en-us/powershell/module/az.automation/import-azautomationrunbook?view=azps-8.3.0)                               | Upload [pre-defined Powershell content](../automation/FirewallToggle.ps1) into the Runbook body.                                                                            |   |
|  6. | Automation Schedule(s) _using Powershell_ |                               [link](https://learn.microsoft.com/en-us/powershell/module/az.automation/import-azautomationrunbook?view=azps-8.3.0)                               | Create the schedules that will execute the Firewall automation.  These had to be created using Powershell instead of the Azure CLI.  No equivalent behavior has been found. |   |

### Resources Created When Complete

1. Azure user-assigned Managed Identity
2. Azure Automation Account
3. Azure PowerShell Runbook

    ![List of resources that will be created when complete.](./assets/automation/listOfResourcesInResourceGroup.png)

## Installation Method - Automated Scripts

BEFORE continuing please make sure all requirements have been met in the section labeled [prerequisites]("#-prerequisites").

1. [Create Automation Infrastructure (BASH script)]("./scripts/automatoin/Firewall-Automation-Infrastructure.sh")

    The [Firewall-Automation-Infrastructure.sh]("./scripts/Firewall-Automation/Firewall-Automation-Infrastructure.sh") script "dot sources" the [Firewall-Automation-Infrastructure-Variables.sh]("./scripts/Firewall-Automation/Firewall-Automation-Infrastructure-Variables.sh").  

_This file must to be adjusted for the specifics of the execution._

### BASH Variables

The BASH variables are exported into environment variables.  

```bash
# Tenant Id for the onmicrosoft.com tenant
export ASB_FW_Tenant_Id=''
export ASB_FW_Subscription_Name=''
export ASB_FW_Base_NSGA_Name='ngsa-asb'
export ASB_FW_Base_Automation_System_Name='firewall-automation'
export ASB_FW_Environment='dev'
export ASB_FW_PowerShell_Runbook_File_Name='Firewall-Automation-Runbook.ps1'
export ASB_FW_Sku='Basic'
export ASB_FW_Location='westus'
export ASB_FW_PowerShell_Runbook_Description='This runbook allocates and de-allocates specific firewalls.  It also enables and disables specific metric and log alerts associated with such activities.'

```

Below will detail what is being executed within the script files for further understanding.  This section is informational only.

#### Adjust Variables

The file [Firewall-Automation-Infrastructure-Variables.sh]("./scripts/Firewall-Automation/Firewall-Automation-Infrastructure-Variables.sh") must be adjusted to include relevant values.

_Potentially sensitive values such as subscription Id have been omitted from the documentation_

```bash
ASB_FW_Tenant_Id=''
ASB_FW_Subscription_Name=''
ASB_FW_Base_NSGA_Name='ngsa-asb'
ASB_FW_Base_Automation_System_Name='firewall-automation'
ASB_FW_Environment='dev'
ASB_FW_PowerShell_Runbook_File_Name='Firewall-Automation-Runbook.ps1'
ASB_FW_Sku='Basic'
ASB_FW_Location='westus'
ASB_FW_PowerShell_Runbook_Description='This runbook automates the allocation and de-allocation of a firewall for the purposes of scheduling.'

```

#### Executing Script

Once the variables are adjusted the script must be run from Visual Studio Code (thick client) using Codespaces.  the script does not require input parameters because they are provided in the variable file mentioned above.

```bash

  ./Firewall-Automation-Infrastructure-Variables.sh

```

To create the schedules execute the PowerShell script Firewall-Automation-Schedule-Creation.ps1.  This script must be executed in Codespaces as well, and must have parameters passed to it.  

```PowerShell

    $ASB_FW_Tenant_Id={tenant Id}
    $ASB_FW_Subscription_Name={subscription name}
    $ASB_FW_Subscription_Id={subscription Id}
    $Automation_Resource_Group='rg-ngsa-asb-firewall-automation-dev'
    $Firewall_Resource_Group='rg-ngsa-asb-dev-hub'
    $Location='eastus'
    $Automation_Account_Name='aa-ngsa-asb-firewall-automation-dev'
    $Sku='Basic'
    $PowerShell_Runbook_Name='rb-ngsa-asb-firewall-automation-dev'
    $Vnet_Name='vnet-eastus-hub'
    $Firewall_Name='fw-eastus'
    $PIP_Name1='pip-fw-eastus-01'
    $PIP_Name2='pip-fw-eastus-02'
    $PIP_Name_Default='pip-fw-eastus-default'
    $Managed_Identity_Name='mi-ngsa-asb-firewall-automation-dev'
    $Base_Schedule_Name='as-ngsa-asb-firewall-automation-dev'
    $Environment='dev'


Firewall-Automation-Schedule-Creation.ps1 
    -Tenant_Id $ASB_FW_Tenant_Id 
    -Subscription_Name $ASB_FW_Subscription_Name
    -Subscription_Id $ASB_FW_Subscription_Id 
    -Resource_Group_Name_for_Automation $Automation_Resource_Group -Resource_Group_Name_with_Firewall $Firewall_Resource_Group 
    -Location $Location
    -Automation_Account_Name $Automation_Account_Name 
    -Sku $Sku 
    -PowerShell_Runbook_Name $PowerShell_Runbook_Name 
    -Vnet_Name $Vnet_Name
    -Firewall_Name $Firewall_Name
    -PIP_Name1 $PIP_Name1
    -PIP_Name2 $PIP_Name2
    -PIP_Name_Default $PIP_Default
    -Managed_Identity_Name $Managed_Identity_Name
    -Base_Schedule_Name $Base_Schedule_Name
    -Environment $Environment

```
