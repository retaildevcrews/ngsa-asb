
Param (
    [Parameter(Mandatory)]
    [String]$Tenant_Id,
    [Parameter(Mandatory)]
    [String]$Subscription_Name,
    [Parameter(Mandatory)]
    [String]$Subscription_Id,
    [Parameter(Mandatory)]
    [String]$Resource_Group_Name_for_Automation,
    [Parameter(Mandatory)]
    [String]$Resource_Group_Name_for_Alerts,
    [Parameter(Mandatory)]
    [String]$Resource_Group_Name_with_Firewall,
    [Parameter(Mandatory)]
    [String]$Location,
    [Parameter(Mandatory)]
    [String]$Automation_Account_Name,
    [Parameter(Mandatory)]
    [String]$Sku,
    [Parameter(Mandatory)]
    [String]$PowerShell_Runbook_Name,
    [Parameter(Mandatory)]
    [String]$Vnet_Name,
    [Parameter(Mandatory)]
    [String]$Firewall_Name,
    [Parameter(Mandatory)]
    [String]$PIP_Name1,
    [Parameter(Mandatory)]
    [String]$PIP_Name2,
    [Parameter(Mandatory)]
    [String]$PIP_Name_Default,
    [Parameter(Mandatory)]
    [String]$Managed_Identity_Name,
    [Parameter(Mandatory)]
    [String]$Base_Schedule_Name,
    [Parameter(Mandatory)]
    [String]$Environment
)

$stop_Time = (Get-Date "21:00:00").AddHours(+4).AddDays(1)
$start_Time = (Get-Date "06:00:00").AddHours(+4).AddDays(1)
$end_Time = (Get-Date $start_Time).AddYears(3)

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
    [String]$subscription_Id,

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
    [String]$pip_Name_1,
      
    [Parameter(Mandatory)]
    [String]$pip_Name_2,
      
    [Parameter(Mandatory)]
    [String]$pip_Name_Default,
      
    [Parameter(Mandatory)]
    [String]$managed_Identity_Name,
      
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
  $params.Add("resource_Group_Name_with_Alerts", "$Resource_Group_Name_for_Alerts")
  $params.Add("subscription_Name", "$subscription_Name")
  $params.Add("vnet_Name", "$vnet_Name")
  $params.Add("firewall_Name", "$firewall_Name")
  $params.Add("pip_Name1", "$pip_Name_1")
  $params.Add("pip_Name2", "$pip_Name_2")
  $params.Add("pip_Name_Default", "$pip_Name_Default")
  $params.Add("managed_Identity_Name", "$managed_Identity_Name")
  $params.Add("action", "$action")

  Register-AzAutomationScheduledRunbook -Parameters $params -ResourceGroupName $Resource_Group_Name_for_Automation -AutomationAccountName $Automation_Account_Name -RunbookName $powerShell_Runbook_Name -ScheduleName $schedule_Name
  
  Publish-AzAutomationRunbook -AutomationAccountName $Automation_Account_Name -Name $powerShell_Runbook_Name -ResourceGroupName $Resource_Group_Name_for_Automation
  
  Write-Host "Completed registering an Azure Automation Schedule to a Automation Runbook."
}

function Authenticate{  
  Connect-AzAccount -UseDeviceAuth  
  Set-AzContext -Subscription $Subscription_Id
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

Authenticate

Import-Modules

$schedule_Name = $Base_Schedule_Name + "-" + $Environment

Write-Host $schedule_Name

$start_Action_Name = $schedule_Name + "-start"
$stop_Action_Name = $schedule_Name + "-stop"

New-Schedule -Automation_Account_Name $Automation_Account_Name -Resource_Group_Name_for_Automation $Resource_Group_Name_for_Automation -schedule_Name $start_Action_Name -start_Time $start_Time -end_Time $end_Time
New-Schedule -Automation_Account_Name $Automation_Account_Name -Resource_Group_Name_for_Automation $Resource_Group_Name_for_Automation -schedule_Name $stop_Action_Name -start_Time $stop_Time -end_Time $stop_Time

Edit-ScheduleAndRunbook -Resource_Group_Name_with_Firewall $Resource_Group_Name_with_Firewall -Resource_Group_Name_for_Automation $Resource_Group_Name_for_Automation -resource_Group_Name_with_Alerts $resource_Group_Name_For_Alerts -tenant_Id $Tenant_Id -schedule_Name $start_Action_Name -powerShell_Runbook_Name $PowerShell_Runbook_Name -Automation_Account_Name $Automation_Account_Name -subscription_Id $Subscription_Id -subscription_Name $Subscription_Name -vnet_Name $Vnet_Name -firewall_Name $Firewall_Name -pip_Name_1 $PIP_Name1 -pip_Name_2 $PIP_Name2 -pip_Name_Default $PIP_Name_Default -managed_Identity_Name $Managed_Identity_Name -action "start"
Edit-ScheduleAndRunbook -Resource_Group_Name_with_Firewall $Resource_Group_Name_with_Firewall -Resource_Group_Name_for_Automation $Resource_Group_Name_for_Automation -resource_Group_Name_with_Alerts $resource_Group_Name_For_Alerts -tenant_Id $Tenant_Id -schedule_Name $stop_Action_Name -powerShell_Runbook_Name $PowerShell_Runbook_Name -Automation_Account_Name $Automation_Account_Name -subscription_Id $Subscription_Id -subscription_Name $Subscription_Name -vnet_Name $Vnet_Name -firewall_Name $Firewall_Name -pip_Name_1 $PIP_Name1 -pip_Name_2 $PIP_Name2 -pip_Name_Default $PIP_Name_Default -managed_Identity_Name $Managed_Identity_Name -action "stop"

#Broken call issues an error of 'Long running operation failed with status 'BadRequest'.
#manual publish step needed.  
# Publish-AzAutomationRunbook -AutomationAccountName $Automation_Account_Name  -Name $PowerShell_Runbook_Name -ResourceGroupName $Resource_Group_Name_for_Automation


# Disable the schedule after creation
Set-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $start_Action_Name -IsEnabled $false -ResourceGroupName $Resource_Group_Name_for_Automation
Set-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $stop_Action_Name  -IsEnabled $false -ResourceGroupName $Resource_Group_Name_for_Automation

# Enable the schedule after creation
Set-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $start_Action_Name -IsEnabled $true -ResourceGroupName $Resource_Group_Name_for_Automation
Set-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $stop_Action_Name  -IsEnabled $true -ResourceGroupName $Resource_Group_Name_for_Automation

# Disable the schedule after creation
# Set-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $start_Action_Name -IsEnabled $false -ResourceGroupName $Resource_Group_Name_for_Automation
# Set-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $stop_Action_Name  -IsEnabled $false -ResourceGroupName $Resource_Group_Name_for_Automation