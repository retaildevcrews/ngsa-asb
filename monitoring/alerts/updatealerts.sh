#!/bin/bash

# exit when any command fails
set -e

if  [ -z "$SUBSCRIPTION_GUID" ] || [ -z "$ASB_HUB_LOCATION" ] || 
    [ -z "$Ngsa_Action_Group_Name" ] || [ -z "$Ngsa_Alert_Email_Name" ] || 
    [ -z "$Ngsa_Alert_Email_Address" ] || [ -z "$Ngsa_Log_Analytics_RG" ] || 
    [ -z "$Ngsa_Log_Analytics_Name" ]
then
  echo "Please set the following env variables to run this script:
  SUBSCRIPTION_GUID
  ASB_HUB_LOCATION
  Ngsa_Action_Group_Name   
  Ngsa_Alert_Email_Name
  Ngsa_Alert_Email_Address
  Ngsa_Log_Analytics_RG
  Ngsa_Log_Analytics_Name"
else
  echo -e  "Applying Scheduled Queries Alerts...\n"
  pushd ./scheduledQueries
  for filename in ./*.json; do
    # get name of alert
    export Alert_Name=`echo $(basename "$filename" .json)`
    
    # output status
    echo "Creating $Alert_Name"

    # update environment specific variables in temporary json file
    cat $filename | envsubst > $filename-temp.json

    # create or update alert
    az rest --method PUT --url "https://management.azure.com/subscriptions/${SUBSCRIPTION_GUID}/resourceGroups/${Ngsa_Log_Analytics_RG}/providers/microsoft.insights/scheduledqueryrules/${Alert_Name}?api-version=2021-08-01" --body @$filename-temp.json

    # remove temporary file
    rm $filename-temp.json

    # output status
    echo -e "Created/updated $Alert_Name \n"
  done
  popd
fi