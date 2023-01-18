# Application Gateway Restart Automation

The instructions below describe how to implement an Azure Automation Runbook that will automate and schedule stopping and starting the application gateways on each spoke. Though the runbook enables stopping and restarting the application gateways, the scheduled jobs created in this section only restart the application gateways.

## Prerequisites

It is assumed that the Firewall Automation has already been set up, as some of the infrastructure created in that process will be reused here. The automation service principal used for firewall automation setup, as well as the associated role assignments need to be reused here.

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

# Create Firewall-Automation-Infrastructure-Variables.sh from template with values from local variables set above.
cat scripts/App-Gateway-Automation/App-Gateway-Automation-Infrastructure-Variables-Template.txt | envsubst > scripts/App-Gateway-Automation/App-Gateway-Automation-Infrastructure-Variables.env

# Set environment variables 
source scripts/App-Gateway-Schedule-Automation/App-Gateway-Automation-Infrastructure-Variables.env

```

## Execute Script

Once the variables are set, the setup script must be run from Visual Studio Code (thick client) using Codespaces. The script does not require input parameters because the required parameters are stored as environment variables when the variable script is run. Run this command from the top-level directory of this repository. A browser with a login prompt will open while the script is running. Complete the login, and the script will continue to run.

```bash
./scripts/App-Gateway-Automation/App-Gateway-Automation-Infrastructure.sh
```
