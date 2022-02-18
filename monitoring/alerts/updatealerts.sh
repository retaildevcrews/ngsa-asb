#!/bin/bash

# exit when any command fails
set -e

scheduledQueryApi='https://management.azure.com/subscriptions/${SUBSCRIPTION_GUID}/resourceGroups/${Ngsa_Log_Analytics_RG}/providers/microsoft.insights/scheduledqueryrules/${Alert_Name}?api-version=2021-08-01'
metricQueryApi='https://management.azure.com/subscriptions/${SUBSCRIPTION_GUID}/resourceGroups/${Ngsa_Log_Analytics_RG}/providers/microsoft.insights/metricAlerts/${Alert_Name}?api-version=2018-03-01'

function deploy_alert(){
    # get name of alert
    export Alert_Name=`echo $(basename "$1" .json)`
    
    # output status
    echo "Creating $Alert_Name"

    # update environment specific variables in temporary json file
    cat $1 | envsubst > $1-temp.json

    query=$(echo $2 | envsubst)

    # create or update alert
    az rest --method PUT --url $query --body @$1-temp.json

    # remove temporary file
    rm $1-temp.json

    # output status
    echo -e "Created/updated $Alert_Name \n"
}

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
    echo "hello" #deploy_alert $filename $scheduledQueryApi
  done
  popd

  echo -e  "Applying Metric Queries Alerts...\n"
  pushd ./metricsAlerts
  for filename in ./*.json; do
    deploy_alert $filename $metricQueryApi
  done
  popd

fi