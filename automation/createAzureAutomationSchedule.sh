#!/bin/bash

# exit when any command fails
set -e

function collectInputParameters(){
  export AutomationResourceGroupName = $1
  export Location = $2
  export AutomationAccountName = $3
  export Sku = 'Basic'
  export Assignee = $4
  export Subscription = $5
  export ResourceGroupNameWithFirewall = $6
  export vnetName = $7
  export firewallName = $8
  export pip_name1 = $9
  export pip_name2 = $10
  export pip_name_default = $11
  export UAMI = $12
  export update = $13
}

function CreateRunbookSchedule(){
  az automation schedule create --resource-group $AutomationResourceGroup --automation-account-name $AutomationAccountName --name $ScheduleName --description $ScheduleDescription --start-time $ScheduleStartTime --expiry-time $ScheduleExpiryTime --frequency $ScheduleFrequency --interval $ScheduleInterval --time-zone $ScheduleTimeZone --advanced-schedule $ScheduleAdvancedSchedule
}

function main(){
  CreateRunbookSchedule
}

main