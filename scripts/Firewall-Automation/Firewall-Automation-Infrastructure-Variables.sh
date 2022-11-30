#!/bin/bash

export ASB_FW_Tenant_Id='16b3c013-d300-468d-ac64-7eda0820b6d3'
export ASB_DEPLOYMENT_NAME='firewall-automation'
export ASB_SPOKE_LOCATION='westus'
export ASB_ENV='dev'
export ASB_FW_Subscription_Name='MCAPS-43649-AUS-DEVCREWS'
export ASB_FW_Base_NSGA_Name='wcnp'
export ASB_FW_Base_Automation_System_Name='firewall-automation'
export ASB_FW_Environment='dev'
export ASB_FW_PowerShell_Runbook_File_Name='Firewall-Automation-Runbook.ps1'
export ASB_FW_Sku='Basic'
export ASB_FW_Location='westus'
export ASB_FW_PowerShell_Runbook_Description='This runbook automates the allocation and de-allocation of a firewall for the purposes of scheduling.'

./saveenv.sh
