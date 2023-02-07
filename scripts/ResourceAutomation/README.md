# Azure Resource Automation

Azure Automation implemenation for bringing up and shutting down Azure resources on a schedule.  This work was implemented in order to provide a flexible way to stop and start costly resources based on a regular schedule.

## Getting Started

These instructions provide steps to create automation infrastructure as well as the runbooks to start/stop resources at a specified time of the day.

The automation currently supports:

- AKS Cluster and Application Gateways set up as pairs in NGSA-ASB repository

### Prerequisites

Requirements for using this bicep deployment:

- Azure subscription
- Account to execute bicep deployments on that subscription (account should have at least contributor role to subscription)
- Log analytics workspace for automation to log to.

## Running the bicep deployment

1. Log into Azure Subscription with Account that has Contributor role
2. Set up the bicep parameters to match your environment, this is done in automation.parameters.json file

    | Parameter Name | Type |Description |
    |----------------|------|-------|
    |automationSuffix| string |String that will be used to name the automation account, managed identity, and role assignment |
    |logAnalyticsWorkspaceId| string |Resource Id for the log analytics workspace, this is fully qualified id wiht subscription , resource group, etc.|
    |resourceStartStopRunbookURL| string |URL to the raw format script that will be used to create the runbooks for stopping and starting the cluster and gateways |
    |scheduleTimezone| string |timezone to use for schedules|
    |logVerbose |bool |turn verbose logging on/off|
    |logProgress|bool |turn log progress on/off|
    |resourcesToAutomate|array[object]|Array of objects that define what needs to be automated  - gateway, and cluster (assumes they are in the same resource group) |

3. Run the following command

   ``` shell
      az deployment sub create \
        --location eastus \
        --template-file /workspaces/ngsa-asb/scripts/ResourceAutomation/automation.bicep \
        --parameters @automation.parameters.json
   ```

   ❗NOTE: Run the above command with --what-if switch to show what changes running the deployment would make

### The following resources are created by running deployment

- Resource Group
- User Assigned Managed Identity
  - Role Assignment
- Automation Account
  - Schedules
  - Runbooks
  - Job Schedules
  - Diagnostic Settings
