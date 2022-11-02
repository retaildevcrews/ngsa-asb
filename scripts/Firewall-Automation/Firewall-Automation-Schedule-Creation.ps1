$tenantId = Get-Content -Path Env:\ASB_FW_Tenant_Id
$subscriptionName = Get-Content -Path Env:\ASB_FW_Subscription_Name
$baseName = Get-Content -Path Env:\ASB_FW_Base_NSGA_Name
$baseAutomationName = Get-Content -Path Env:\ASB_FW_Base_Automation_System_Name
$environment = Get-Content -Path Env:\ASB_FW_Environment
#$runbookFileName = Get-Content -Path Env:\ASB_FW_PowerShell_Runbook_File_Name
#$sku = Get-Content -Path Env:\ASB_FW_Sku
$location = Get-Content -Path Env:\ASB_FW_Location
#$runbookDescription = Get-Content -Path Env:\ASB_FW_PowerShell_Runbook_Description


function New-Schedule {

  param (
      [parameter(Mandatory)]
      [String]$Automation_Account_Name,
      
      [parameter(Mandatory)]
      [String]$Resource_Group_Name_for_Automation,
      
      [Parameter(Mandatory)]
      [String]$schedule_Name,
      
      [Parameter(Mandatory)]
      [String]$start_Time,
      
      [Parameter(Mandatory)]
      [String]$end_Time
  )

  Write-Host "Creating new Azure Automation Schedule..."
 
  
  New-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $schedule_Name -StartTime $start_Time -ExpiryTime $end_Time -DayInterval 1 -ResourceGroupName $Resource_Group_Name_for_Automation
  
  Write-Host "Completed creating new Azure Automation Schedule."

}

# Links the Runbook and Schedule
function Edit-ScheduleAndRunbook {

  param (
    [Parameter(Mandatory)]
    [String]$Resource_Group_Name_with_Firewall,

    [Parameter(Mandatory)]
    [String]$Resource_Group_Name_for_Automation,
      
    [Parameter(Mandatory)]
    [String]$schedule_Name,

    [Parameter(Mandatory)]
    [String]$powerShell_Runbook_Name,
      
    [Parameter(Mandatory)]
    [String]$Automation_Account_Name,

    [Parameter(Mandatory)]
    [String]$tenant_Id,

    [Parameter(Mandatory)]
    [String]$Resource_Group_Name_with_Alerts,

    [Parameter(Mandatory)]
    [String]$subscription_Name,
      
    [Parameter(Mandatory)]
    [String]$vnet_Name,
      
    [Parameter(Mandatory)]
    [String]$firewall_Name,
      
    [Parameter(Mandatory)]
    [String]$pip_Name1,
      
    [Parameter(Mandatory)]
    [String]$pip_Name2,
      
    [Parameter(Mandatory)]
    [String]$pip_Name_Default,
      
    [Parameter(Mandatory)]
    [String]$managed_Identity_Name,

    [Parameter(Mandatory)]
    [String]$Location,
      
    [Parameter(Mandatory)]
    [String]$action

  )

Write-Host "Registering an Azure Automation Schedule to a Automation Runbook..."
  $error.Clear()

  $params = @{}
  $params.Add("resource_Group_Name_with_Firewall", "$Resource_Group_Name_with_Firewall")
  $params.Add("resource_Group_Name_for_Automation", "$Resource_Group_Name_for_Automation") 
  $params.Add("automation_Account_Name", "$Automation_Account_Name")  
  $params.Add("tenant_Id", "$tenant_Id")
  $params.Add("resource_Group_Name_with_Alerts", "$Resource_Group_Name_with_Alerts")
  $params.Add("subscription_Name", "$subscription_Name")
  $params.Add("vnet_Name", "$vnet_Name")
  $params.Add("firewall_Name", "$firewall_Name")
  $params.Add("pip_Name1", "$pip_Name1")
  $params.Add("pip_Name2", "$pip_Name2")
  $params.Add("pip_Name_Default", "$pip_Name_Default")
  $params.Add("managed_Identity_Name", "$managed_Identity_Name")
  $params.Add("environment", "$Environment")
  $params.Add("action", "$action")
  $params.Add("location", "$Location")

  Register-AzAutomationScheduledRunbook -Parameters $params -ResourceGroupName $Resource_Group_Name_for_Automation -AutomationAccountName $Automation_Account_Name -RunbookName $powerShell_Runbook_Name -ScheduleName $schedule_Name
  
  Write-Host "Completed registering an Azure Automation Schedule to a Automation Runbook."
}

function Authenticate{  
  Connect-AzAccount -UseDeviceAuth  
  Set-AzContext -Subscription $Subscription_Name
}

function Import-Modules{
  Write-Host "Installing & Importing Azure Powershell Az Module for Automation."

  Install-Module -Name Az.Automation -Force | out-null
  Import-Module -Name Az.Automation -Force | out-null

  Write-Host "Installing & Importing Azure Powershell Az Module for Monitor."

  Install-Module -Name Az.Monitor -Force | out-null
  Import-Module -Name Az.Monitor -Force | out-null

  Write-Host "Completed installing & importing Azure Powershell Az Modules for Authentication and Monitor."
}
  $automationResourceGroup = "rg-" + $baseName + "-" + $baseAutomationName + "-" + $environment
  $firewallResourceGroup = "rg-" + $baseName + "-" + $environment + "-hub"
  $alertsResourceGroup = "rg-" + $baseName + "-" + $environment
  $automationAccountName = "aa-" + $baseName + "-" + $baseAutomationName + "-" + $environment
  $runbookName = "rb-" + $baseName + "-" + $baseAutomationName + "-" + $environment
  $managedIdentityName = "mi-" + $baseName + "-" + $baseAutomationName + "-" + $environment

  $vnetName = "vnet-" + $location + "-hub"

  $firewallName = "fw-" + $location
  $publicIpName1 = "pip-fw-" + $location + "-01"
  $publicIpName2 = "pip-fw-" + $location + "-02"
  $publicIpNameDefault = "pip-fw-" + $location + "-default"
  $baseScheduleName = "as-" + $baseName + "-" + $baseAutomationName + "-" + $Environment


  $stop_Time = (Get-Date "21:00:00").AddHours(+4).AddDays(1)
  $start_Time = (Get-Date "06:00:00").AddHours(+4).AddDays(1)
  $end_Time = (Get-Date $start_Time).AddYears(3)

Authenticate -Subscription_Name $subscriptionName

Import-Modules

$start_Action_Name = $baseScheduleName + "-start"
$stop_Action_Name = $baseScheduleName + "-stop"

New-Schedule -Automation_Account_Name $automationAccountName -Resource_Group_Name_for_Automation $automationResourceGroup -schedule_Name $start_Action_Name -start_Time $start_Time -end_Time $end_Time
New-Schedule -Automation_Account_Name $automationAccountName -Resource_Group_Name_for_Automation $automationResourceGroup -schedule_Name $stop_Action_Name -start_Time $stop_Time -end_Time $stop_Time

Edit-ScheduleAndRunbook -Resource_Group_Name_with_Firewall $firewallResourceGroup -Location $location -Resource_Group_Name_for_Automation $automationResourceGroup -resource_Group_Name_with_Alerts $alertsResourceGroup -tenant_Id $tenantId -schedule_Name $start_Action_Name -powerShell_Runbook_Name $runbookName -Automation_Account_Name $automationAccountName -subscription_Name $subscriptionName -vnet_Name $vnetName -firewall_Name $firewallName -pip_Name1 $publicIpName1 -pip_Name2 $publicIpName2 -pip_Name_Default $publicIpNameDefault -managed_Identity_Name $managedIdentityName -action "start"
Edit-ScheduleAndRunbook -Resource_Group_Name_with_Firewall $firewallResourceGroup -Location $location -Resource_Group_Name_for_Automation $automationResourceGroup -resource_Group_Name_with_Alerts $alertsResourceGroup -tenant_Id $tenantId -schedule_Name $stop_Action_Name -powerShell_Runbook_Name $runbookName -Automation_Account_Name $automationAccountName -subscription_Name $subscriptionName -vnet_Name $vnetName -firewall_Name $firewallName -pip_Name1 $publicIpName1 -pip_Name2 $publicIpName2 -pip_Name_Default $publicIpNameDefault -managed_Identity_Name $managedIdentityName -action "stop"

Publish-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name $runbookName -ResourceGroupName $automationResourceGroup

# Disable the schedule after creation
Set-AzAutomationSchedule -AutomationAccountName $automationAccountName -Name $start_Action_Name -IsEnabled $false -ResourceGroupName $automationResourceGroup
Set-AzAutomationSchedule -AutomationAccountName $automationAccountName -Name $stop_Action_Name  -IsEnabled $false -ResourceGroupName $automationResourceGroup

# Enable the schedule after creation
#Set-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $start_Action_Name -IsEnabled $true -ResourceGroupName $Resource_Group_Name_for_Automation
#Set-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $stop_Action_Name  -IsEnabled $true -ResourceGroupName $Resource_Group_Name_for_Automation