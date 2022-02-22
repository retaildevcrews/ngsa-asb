# Create NGSA Pre-prod Environment Alerts

The JSON files in this directory contain the properties for the alerts described in [Alerts.md](../Alerts.md).  The `updatealerts.sh` script can be used to quickly create or update all of the alerts using the Azure CLI instead of the portal. The JSON file properties can be updated with different configuration values to update the corresponding alerts.  It is recommended to test out any query updates in Log Analytics before updating the alert to ensure the query is valid and returns expected results.

## Run script to create or update NGSA Pre-prod Alerts

### Set required environment variables (if not set already)

```bash

# Verify you are in the correct subscription and you are the owner
# Use az account set -s <sub> to change the sub if required
az account show -o table

# get subscription id
export Ngsa_Subscription_Guid=$(eval az account show -o tsv --query id)

# set name of existing resource group containing log analytics
export Ngsa_Common_Services_RG="${ASB_RG_CORE}"

# set name of existing log analytics instance
export Ngsa_Log_Analytics_Name="${ASB_LA_NAME}"

#set the location of the alert resource
export Ngsa_Alert_Location="${ASB_HUB_LOCATION}"

```

### Create Action Group

```bash

# set name of action group for alerts
export Ngsa_Action_Group_Name="ngsa-ag"
export Ngsa_Alert_Email_Name="NGSA-Alert"
export Ngsa_Alert_Email_Address="CSENextGenK8s@microsoft.com"

# create the action group (if it doesnt exist already)
az monitor action-group create --name $Ngsa_Action_Group_Name --resource-group $Ngsa_Common_Services_RG --action email $Ngsa_Alert_Email_Name $Ngsa_Alert_Email_Address

# update the group with as many email addresses as required (optional)
az monitor action-group update -n $Ngsa_Action_Group_Name -g $Ngsa_Common_Services_RG --add-action email {Name} {email address}

```

### Update json files to make desired alert changes

Before running the script, make the desired changes to the alerts by saving changes to the associated json files.

Common properties that may need updating:

- description
- source -> query
- schedule -> frequencyInMinutes
- schedule -> timeWindowInMinutes
- action -> severity
- action -> throttlingInMin (how long to wait before re-triggering the alert)
- action -> trigger -> threshold
- action -> trigger -> consecutiveBreach

### Run the script to create or update existing alerts

```bash

# make sure you are in the /docs/alerts folder

# run script to update or create alerts while passing environment argument
./updatealerts.sh [dev | pre]


```
