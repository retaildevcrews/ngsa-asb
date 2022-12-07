# Web Application Firewall (WAF) Allocation/De-Allocation Automation

Azure Firewall has [costs (Azure Firewall pricing link)](https://azure.microsoft.com/en-gb/pricing/details/azure-firewall/#pricing) associated with it which can be optimized by allocating and de-allocating the firewall when appropriate.  Below describes the mechanism to implement an Azure Automation Runbook that will allocate and de-allocate the firewall on a schedule as well as enable and disable the alerts associated with this activity to minimize nonessential systems communications.

## Before Beginning

🛑 IMPORTANT: Prevent accidental `Sensitive Data` commits for the variables file with `git update-index --assume-unchanged scripts/Firewall-Automation/Firewall-Automation-Infrastructure-Variables.sh`

## Login to Azure

```bash
az login 

###  show your Azure accounts
az account list -o table

###  select the Azure subscription if necessary
az account set -s {subscription name or Id}
```

The execution of the script requires a ServicePrincipal to be created as part of the provisioning process:

ServicePrincipal | Purpose | Graph Permissions |
-----------------|---------|-------------------|
 e.g:  firewall-automation-sp-\<env> | Application Identity |

## Service Principal Permissions

Role assignment scoped to the subcription neeeds to be created and assigned to the service principal **firewall-automation-sp-\<env>**.

This service principal requires role assignments listed in the table below to enable Powershell Connect and Automation commands to work.

| Role | Type | Scope |
| --- | --- | --- |
| Automation Contributor  | App | Subscription |
| Managed Identity Operator  | App | Subscription |

## Create Service Principal and to do the role assignments

```bash

# Replace the correct SP name 
local automationClientSecret=$(az ad sp create-for-rbac -n http://firewall-automation-sp-<env> --query password -o tsv)

# Replace the correct SP name 
local automationClientId=$(az ad sp show --id http://firewall-automation-sp-<env> --query appId -o tsv)

# Replace the correct SubscriptionId
az role assignment create --role "'Managed Identity Operator'" --assignee $automationClientId --scope "/subscriptions/<subscription_Id>"

# Replace the correct SubscriptionId
az role assignment create --role "Automation Contributor'" --assignee $automationClientId --scope "/subscriptions/<subscription_Id>"

```

### Prerequisites

Before proceeding, verify that the correct version of Azure CLI and required extensions have been installed:

- Azure CLI 2.0 or greater
  - Run the command `az version`
  - If the correct version is not installed, install Azure CLI from [here](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

- Azure CLI Extension for Automation
  - Run the command `az extension show --name automation -o table`
  - If the Azure CLI extension for automation is not installed, install it from [here](https://github.com/Azure/azure-cli-extensions/tree/main/src/automation#how-to-use).

- Azure CLI Extension for Monitor
  - Run the command `az extension show --name monitor-control-service -o table`
  - If the Azure CLI extension for monitor-control-service is not installed, install it from [here](https://github.com/Azure/azure-cli-extensions/tree/main/src/monitor-control-service#how-to-use)

- Azure Powershell modules
  - Open up a PowerShell Terminal
  - [Install Azure PowerShell Modules](https://learn.microsoft.com/en-us/powershell/azure/install-az-ps?view=latest#installation) from the prompt using the command `Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force`

_The Azure CLI Automation extension is in an experimental stage.  Currently it does not implement all functionality needed.  As a result the the Az Module, specifically for automation, monitoring,  and authentication can be used at the time of writing._

### Parameters Needed to Proceed

#### Parameters for Bash Execution

| Parameter Name                        |                                             Example Value                                             | Script Needed For |
| ------------------------------------- | :---------------------------------------------------------------------------------------------------: | ----------------- |
| ASB_FW_TenantId                       |                                  00000000-0000-0000-0000-000000000000                                 | bash              |
| ASB_DEPLOYMENT_NAME                   |                                          firewall-automation                                          | bash              |
| ASB_ENV                               |                                                  dev                                                  | bash              |
| ASB_FW_Subscription_Name              |                                              JoFultz-Team                                             | bash              |
| ASB_FW_Base_NGSA_Name                 |                                                ngsa-asb                                               | bash              |
| ASB_FW_Base_Automation_System_Name    |                                                  bash                                                 | bash              |
| ASB_FW_Environment                    |                                                  dev                                                  | bash              |
| ASB_FW_PowerShell_Runbook_File_Name   |                                    Firewall-Automation-Runbook.ps1                                    | bash              |
| ASB_FW_Location                       |                                                 westus                                                | bash              |
| ASB_FW_Sku                            |                                                 Basic                                                 | bash              |
| ASB_FW_PowerShell_Runbook_Description | This runbook automates the allocation and de-allocation of a firewall for the purposes of scheduling. | bash              |
| ASB_FW_Environment                    |                                                  dev                                                  | bash              |
| firewallName                          |                                              fw-centralus                                             | bash              |

#### Parameters for PowerShell Execution

The powershell file needed to create the runbook schedules is called from the bash script, and re-uses the environment variables to then generate all parameters needed.  

### Infrastructure & Assets Creation List

The following infrastructure assets should be established in the subscription with the Azure Firewall(s) to be managed once all aspects of this document are fulfilled.  Though six (6) items are listed, technically one (1) item is an import of content to the body of the Azure Automation Runbook so this item will not show up in the portal without deeper investigation.  

|     | Resource                                  |                                                                                       Links                                                                                      | Description                                                                                                                                                                 |   |
| :-: | :---------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | - |
|  1. | Resource Group                            |                                                 [link](https://learn.microsoft.com/en-us/cli/azure/manage-azure-groups-azure-cli)                                                | Create "sibling" resource group in subscription for Azure Automation infrastructure.                                                                                        |   |
|  2. | Automation Account                        |                     [link](https://learn.microsoft.com/en-us/azure/templates/microsoft.automation/automationaccounts?pivots=deployment-language-arm-template)                    | Create an Automation Account that will execute the automation.                                                                                                              |   |
|  3. | User-Assigned Managed Identity            | [link](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/how-manage-user-assigned-managed-identities?pivots=identity-mi-methods-azcli) | Create an identity for the Automation Account.                                                                                                                              |   |
|  4. | Automation Runbook with Powershell        |                                      [link](https://learn.microsoft.com/en-us/azure/automation/automation-runbook-types#powershell-runbooks)                                     | Create a Runbook of type Powershell.                                                                                                                                        |   |
|  5. | Powershell Content in Runbook             |                               [link](https://learn.microsoft.com/en-us/powershell/module/az.automation/import-azautomationrunbook?view=azps-8.3.0)                               | Upload [pre-defined Powershell content](../scripts/Firewall-Automation/Firewall-Automation-Runbook.ps1) into the Runbook body.                                                                            |   |
|  6. | Automation Schedule(s) _using Powershell_ |                               [link](https://learn.microsoft.com/en-us/powershell/module/az.automation/import-azautomationrunbook?view=azps-8.3.0)                               | Create the schedules that will execute the Firewall automation.  These had to be created using Powershell instead of the Azure CLI.  No equivalent behavior has been found. |   |

### Resources Created When Complete

1. Azure user-assigned Managed Identity
2. Azure Automation Account
3. Azure PowerShell Runbook

    ![List of resources that will be created when complete.](./assets/Firewall-Automation/listOfResourcesInResourceGroup.png)

## Installation Method - Automated Scripts

BEFORE continuing please make sure all requirements have been met in the section labeled [prerequisites](#prerequisites).

### Adjust Environment Variable Values

The file [Firewall-Automation-Infrastructure-Variables.sh](../scripts/Firewall-Automation/Firewall-Automation-Infrastructure-Variables.sh) must be updated to include relevant values for all of the required environment variables. It will be run by the script [Firewall-Automation-Infrastructure.sh](../scripts/Firewall-Automation/Firewall-Automation-Infrastructure.sh) as part of the automated setup.

Note: _Potentially sensitive values such as subscription Id have been omitted from the documentation_

## TODO: Do we need to add special instructions to add automationClientSecret and  automationClientId to Firewall-Automation-Infrastructure-Variables.sh file ???

## TODO: Need to create the triage item to try to automate the SP creation and inject those values into the variables file 

```bash
export ASB_FW_Tenant_Id=''
export ASB_FW_Subscription_Name=''
export ASB_FW_Base_NSGA_Name='ngsa-asb'
export ASB_FW_Base_Automation_System_Name='firewall-automation'
export ASB_FW_Environment='dev'
export ASB_FW_PowerShell_Runbook_File_Name='Firewall-Automation-Runbook.ps1'
export ASB_FW_Sku='Basic'
export ASB_FW_Location='westus'
export ASB_FW_PowerShell_Runbook_Description='This runbook allocates and de-allocates specific firewalls.  It also enables and disables specific metric and log alerts associated with such activities.'
export ASB_SP_CONNECT_AZ_CLIENTID='' # Value from local variable @automationClientId from Section "Create Service Principal"
export ASB_SP_CONNECT_AZ_SECRET='' # Value from local variable @automationClientSecret from Section "Create Service Principal"
```

### Execute Script

Once the variables are updated, the setup script must be run from Visual Studio Code (thick client) using Codespaces. The script does not require input parameters because the required parameters are stored as environment variables when it runs the variable script. Run this command from the top-level directory of this repository.

```bash
  ./scripts/Firewall-Automation/Firewall-Automation-Infrastructure.sh
```
