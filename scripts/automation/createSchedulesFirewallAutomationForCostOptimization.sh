#!/bin/bash

# exit when any command fails
set -e

function collectInputParameters(){
 if [[ "$#" -ne 5 ]]; then
      echo "Please provide the 1. Automation Resource Group Name, 2. Location, 3. Automation Account Name, 4. Subscription Name.  5.  Core ASB Resource Group Name  You passed in "$#" parameters."
      exit 1
  else 
    export AutomationResourceGroupName=$1
    export Location=$2
    export AutomationAccountName=$3
    export Subscription=$4
    export Sku='Basic'
    export ASBResourceGroupCore=rg-$5
    export IdentityName='mi_wcnp_automation'

    # export AssigneeObjectId=$4
    # export ResourceGroupNameWithFirewall=$6
    # export vnetName=$7
    # export firewallName=$8
    # export pip_name1=$9
    # export pip_name2=$10
    # export pip_name_default=$11
    # export UAMI=$12
    # export update=$13
  fi
}

function CreateRunbookSchedule(){
  echo "Creating schedule for runbook $1 in $AutomationResourceGroup for $AutomationAccountName..."
  az automation schedule create --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --name $ScheduleName --description $ScheduleDescription --start-time $ScheduleStartTime --expiry-time $ScheduleExpiryTime --frequency $ScheduleFrequency --interval $ScheduleInterval --time-zone $ScheduleTimeZone --advanced-schedule $ScheduleAdvancedSchedule
  echo "Completed creating schedule for runbook $1 in $AutomationResourceGroup for $AutomationAccountName."
}

function main(){
  echo "Starting Azure Automation Schedule creation script..."
  CreateRunbookSchedule $1 $2 $3 $4 $5 $6 $7 $8 $9
  echo "Completed starting Azure Automation Schedule creation script."
}


start_time="$(date -u +%s)"
main $1 $2 $3 $4 $5
end_time="$(date -u +%s)"

elapsed="$(($end_time-$start_time))"
eval "echo Elapsed time: $(date -ud "@$elapsed" +'$((%s/3600/24)) days %H hr %M min %S sec')"