# Application Gateway Restart Automation

The instructions below describe how to implement an Azure Automation Runbook that will automate and schedule stopping and starting the application gateways in the ngsa-asb setup. Though the runbook enables stopping and restarting the application gateways, the scheduled jobs created in this section only restart the application gateways.

## Prerequisites

It is assumed that the Firewall Automation has already been set up, as some of the infrastructure created in that process will be reused here, specifically

- the automation resource group
- the automation account
- the user-assigned managed identity and associated role assignments

Additionally, the automation service principal used for firewall automation setup, as well as the associated role assignments need to be reused here. The service principal's client ID and secret need to still be accessible in the keyvault. If they have been deleted, they can be recreated using [these steps](./Firewall-Automation.md#create-service-principal-and-role-assignments-and-store-secrets-in-key-vault).

## Set Environment Variables

The file ***App-Gateway-Automation-Infrastructure-Variables.env*** must be created from the template to include relevant values for all of the required environment variables. It will be used by the script ***App-Gateway-Automation-Infrastructure.sh*** as part of the automated setup. The file ***App-Gateway-Automation-Infrastructure-Variables.env*** will be ignored by git.

```bash

# Set input variable values.
export tenantId=$(az account show -o tsv --query tenantId)
export subscriptionName=$(az account show -o tsv --query name)
export deploymentName='' #e.g wcnptest
export environment='' #e.g dev or preprod
export location='' #e.g eastus
export keyVaultName=''#e.g kv-aks-abcdefg
export keyVaultRGName=''#key vault resource group name

export agwAutomationAccountName=''# automation acount name
export agwAutomationAccountRGName=''# automation acount resource group name
export agwName=''# application gateway name
export agwRGName=''# application gateway resource group name
export agwUAMIName=''# user-assigned managed identity name

# Create App-Gateway-Automation-Infrastructure-Variables.sh from template with values from local variables set above.
cat scripts/App-Gateway-Automation/App-Gateway-Automation-Infrastructure-Variables-Template.txt | envsubst > scripts/App-Gateway-Automation/App-Gateway-Automation-Infrastructure-Variables.env

# Set environment variables 
source scripts/App-Gateway-Schedule-Automation/App-Gateway-Automation-Infrastructure-Variables.env

```

## Execute Script

Once the variables are set, the setup script must be run from Visual Studio Code (thick client) using Codespaces. The script does not require input parameters because the required parameters are stored as environment variables when the variable script is run. Run this command from the top-level directory of this repository. A browser with a login prompt will open while the script is running. Complete the login, and the script will continue to run. This script will create a runbook and one scheduled job using the inputs from the set environment variables.

```bash
./scripts/App-Gateway-Automation/App-Gateway-Automation-Infrastructure.sh "create_run_book"
```

## Creating Additional Scheduled Jobs

To create additional scheduled jobs for the same runbook, update the environment variables as needed by repeating [this step](#set-environment-variables). Next, run the script as shown below.

```bash
./scripts/App-Gateway-Automation/App-Gateway-Automation-Infrastructure.sh
```