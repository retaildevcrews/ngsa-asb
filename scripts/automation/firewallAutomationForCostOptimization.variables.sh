export ASB_FW_Tenant_Id='' # Tenant Id for the onmicrosoft.com tenant
export ASB_FW_Subscription_Name='' # Suscription Id for Jofultz-Team
export ASB_FW_Base_NSGA_Name='ngsa-asb'
export ASB_FW_Base_Automation_System_Name='firewall-automation'
export ASB_FW_Environment='dev'
export ASB_FW_PowerShell_Runbook_File_Name='firewallAutomationForCostOptimization.Runbook.ps1' # Powershell based runbook file name.
export ASB_FW_Sku='Basic' # Sku for the Automation Account
export ASB_FW_Location='westus' # Location for resource creation
export ASB_FW_PowerShell_Runbook_Description='This runbook automates the allocation and de-allocation of a firewall for the purposes of scheduling.' # Description for the runbook.

echo
echo "-------------------------------------------------------------------"
echo "         Environment Variables for ASB Firewall Automation         "
echo "-------------------------------------------------------------------"
echo
env | grep ^ASB_FW_ | while read kv; do echo "${kv}"; done
echo
echo "-------------------------------------------------------------------"
echo "         Environment Variables for ASB Firewall Automation         "
echo "-------------------------------------------------------------------"
echo