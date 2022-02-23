#!/bin/bash

# exit when any command fails
set -e

if [ -z "$1" ]
  then
    echo "No target evironment argument supplied. Please provide target environment (e.g. pre, dev)"
    exit;
fi

env=$1
scheduledQueryApi='https://management.azure.com/subscriptions/${Ngsa_Subscription_Guid}/resourceGroups/${Ngsa_Common_Services_RG}/providers/microsoft.insights/scheduledqueryrules/${Alert_Name}?api-version=2021-08-01'
metricQueryApi='https://management.azure.com/subscriptions/${Ngsa_Subscription_Guid}/resourceGroups/${Ngsa_Common_Services_RG}/providers/microsoft.insights/metricAlerts/${Alert_Name}?api-version=2018-03-01'

function deploy_alert(){

    if ! [ -a $1 ]
    then
      echo "Warning: File $1 doesn't exist...skipping"
      return;
    fi
    
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

if  [ -z "$Ngsa_Subscription_Guid" ] || [ -z "$Ngsa_Alert_Location" ] || 
    [ -z "$Ngsa_Action_Group_Name" ] || [ -z "$Ngsa_Common_Services_RG" ] || 
    [ -z "$Ngsa_Log_Analytics_Name" ]
then
  echo "Please set the following env variables to run this script:
  Ngsa_Subscription_Guid
  Ngsa_Alert_Location
  Ngsa_Action_Group_Name   
  Ngsa_Common_Services_RG
  Ngsa_Log_Analytics_Name"
else
  echo -e  "Applying Scheduled Queries Alerts...\n"
  pushd ./scheduledQueries/$env
  for filename in ./*.json; do
    deploy_alert $filename $scheduledQueryApi
  done
  popd
    
  echo -e  "Applying Metric Alerts...\n"
  pushd ./metricsAlerts/$env
  for filename in ./*.json; do
    deploy_alert $filename $metricQueryApi
  done
  popd
fi
