#!/bin/bash

export ASB_FW_Tenant_Id=''
export ASB_DEPLOYMENT_NAME='firewall-automation'
export ASB_SPOKE_LOCATION='eastus'
export ASB_ENV='dev'
export ASB_FW_Subscription_Name=''
export ASB_FW_Base_NSGA_Name='wcnp'
export ASB_FW_Base_Automation_System_Name='firewall-automation'
export ASB_FW_Environment='dev'
export ASB_FW_PowerShell_Runbook_File_Name='Firewall-Automation-Runbook.ps1'
export ASB_FW_Sku='Basic'
export ASB_FW_Location='eastus'
export ASB_FW_PowerShell_Runbook_Description='This runbook automates the allocation and de-allocation of a firewall for the purposes of scheduling.'

./saveenv.sh
