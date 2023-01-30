#!/bin/bash

# check for required environment variables
if [ ! "$DIAGNOSTIC_SETTING_NAME" ]; then
  echo "DIAGNOSTIC_SETTING_NAME is required"
  exit 1
elif [ ! "$AUTOMATION_ACCOUNT_NAME" ]; then
  echo "AUTOMATION_ACCOUNT_NAME is required"
  exit 1
elif [ ! "$AUTOMATION_ACCOUNT_RG" ]; then
  echo "AUTOMATION_ACCOUNT_RG is required"
  exit 1
elif [ ! "$LA_WORKSPACE_NAME" ]; then
  echo "LA_WORKSPACE_NAME is required"
  exit 1
elif [ ! "$LA_WORKSPACE_RG" ]; then
  echo "LA_WORKSPACE_RG is required"
  exit 1
fi

# fetch log analytics workspace id where to send logs
LA_WORKSPACE_ID=$(
  az monitor log-analytics workspace show \
    --name "$LA_WORKSPACE_NAME" \
    --resource-group "$LA_WORKSPACE_RG" \
    --query "id" -o tsv
)

# exit early with message if log analytics workspace can't be found
if [ ! "$LA_WORKSPACE_ID" ]; then
  echo "log analytics workspace not found"
  exit 1
fi

# create new diagnostic setting to send log to log analytics in the AzureDianostics table
az monitor diagnostic-settings create \
  --name "$DIAGNOSTIC_SETTING_NAME" \
  --resource "$AUTOMATION_ACCOUNT_NAME" \
  --resource-group "$AUTOMATION_ACCOUNT_RG" \
  --resource-type "Microsoft.Automation/AutomationAccounts" \
  --export-to-resource-specific false \
  --logs '[{"category": "JobLogs", "enabled": true},{"category": "JobStreams","enabled": true}]' \
  --workspace "$LA_WORKSPACE_ID"
