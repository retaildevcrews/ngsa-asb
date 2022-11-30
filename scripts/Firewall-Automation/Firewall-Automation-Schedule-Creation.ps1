foreach ($line in (Get-Content -Path './firewall-automation-dev-westus.env')) {
  if ($line.Contains('export ')) {
    $line = $line -replace 'export ', ''
    $line = $line.Replace("'", "")
    $lineItems = $line -split '='
    [System.Environment]::SetEnvironmentVariable( $lineItems[0], $lineItems[1] )
  }
}

$tenantId = $env:ASB_FW_Tenant_Id
$subscriptionName = $env:ASB_FW_Subscription_Name
$baseName = $env:ASB_FW_Base_NSGA_Name
$baseAutomationName = $env:ASB_FW_Base_Automation_System_Name
$environment = $env:ASB_FW_Environment
$location = $env:ASB_FW_Location

Write-Output((Get-ChildItem env:*).GetEnumerator() | Sort-Object Name | Out-String)

function New-Schedule {

  param (
    [parameter(Mandatory)]
    [String]$automation_Account_Name,
      
    [parameter(Mandatory)]
    [String]$resource_Group_Name_for_Automation,
      
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
    [String]$resource_Group_Name_with_Firewall,

    [Parameter(Mandatory)]
    [String]$resource_Group_Name_for_Automation,
      
    [Parameter(Mandatory)]
    [String]$schedule_Name,

    [Parameter(Mandatory)]
    [String]$powerShell_Runbook_Name,
      
    [Parameter(Mandatory)]
    [String]$automation_Account_Name,

    [Parameter(Mandatory)]
    [String]$tenant_Id,

    [Parameter(Mandatory)]
    [String]$resource_Group_Name_with_Alerts,

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
    [String]$location,
      
    [Parameter(Mandatory)]
    [String]$action

  )

  Write-Host "Registering an Azure Automation Schedule to a Automation Runbook..."
  $error.Clear()

  $params = @{}
  $params.Add("resource_Group_Name_with_Firewall", "$resource_Group_Name_with_Firewall")
  $params.Add("resource_Group_Name_for_Automation", "$resource_Group_Name_for_Automation") 
  $params.Add("automation_Account_Name", "$automation_Account_Name")  
  $params.Add("tenant_Id", "$tenant_Id")
  $params.Add("resource_Group_Name_with_Alerts", "$resource_Group_Name_with_Alerts")
  $params.Add("subscription_Name", "$subscription_Name")
  $params.Add("vnet_Name", "$vnet_Name")
  $params.Add("firewall_Name", "$firewall_Name")
  $params.Add("pip_Name1", "$pip_Name1")
  $params.Add("pip_Name2", "$pip_Name2")
  $params.Add("pip_Name_Default", "$pip_Name_Default")
  $params.Add("managed_Identity_Name", "$managed_Identity_Name")
  $params.Add("environment", "$environment")
  $params.Add("action", "$action")
  $params.Add("location", "$location")

  Register-AzAutomationScheduledRunbook -ResourceGroupName $resource_Group_Name_for_Automation -AutomationAccountName $automation_Account_Name -RunbookName $powerShell_Runbook_Name -ScheduleName $schedule_Name -Parameters $params
  
  Write-Host "Completed registering an Azure Automation Schedule to a Automation Runbook."
}

function Authenticate {  
  Connect-AzAccount -UseDeviceAuth  
  Set-AzContext -Subscription $subscriptionName
}

function Import-Modules {
  Write-Host "Installing & Importing Azure Powershell Az Module for Automation."

  # Install-Module -Name Az.Automation -Force | out-null
  # Import-Module -Name Az.Automation -Force | out-null

  Write-Host "Installing & Importing Azure Powershell Az Module for Monitor."

  # Install-Module -Name Az.Monitor -Force | out-null
  # Import-Module -Name Az.Monitor -Force | out-null

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
$baseScheduleName = "as-" + $baseName + "-" + $baseAutomationName + "-" + $environment


$stop_Time = (Get-Date "21:00:00").AddHours(+4).AddDays(1)
$start_Time = (Get-Date "06:00:00").AddHours(+4).AddDays(1)
$end_Time = (Get-Date $start_Time).AddYears(3)

Authenticate -Subscription_Name $subscriptionName

Import-Modules

$start_Action_Name = $baseScheduleName + "-start"
$stop_Action_Name = $baseScheduleName + "-stop"

New-Schedule -automation_Account_Name $automationAccountName -resource_Group_Name_for_Automation $automationResourceGroup -schedule_Name $start_Action_Name -start_Time $start_Time -end_Time $end_Time
New-Schedule -automation_Account_Name $automationAccountName -resource_Group_Name_for_Automation $automationResourceGroup -schedule_Name $stop_Action_Name -start_Time $stop_Time -end_Time $stop_Time

Edit-ScheduleAndRunbook -resource_Group_Name_with_Firewall $firewallResourceGroup -Location $location -resource_Group_Name_for_Automation $automationResourceGroup -resource_Group_Name_with_Alerts $alertsResourceGroup -tenant_Id $tenantId -schedule_Name $start_Action_Name -powerShell_Runbook_Name $runbookName -automation_Account_Name $automationAccountName -subscription_Name $subscriptionName -vnet_Name $vnetName -firewall_Name $firewallName -pip_Name1 $publicIpName1 -pip_Name2 $publicIpName2 -pip_Name_Default $publicIpNameDefault -managed_Identity_Name $managedIdentityName -action "start"
Edit-ScheduleAndRunbook -resource_Group_Name_with_Firewall $firewallResourceGroup -Location $location -resource_Group_Name_for_Automation $automationResourceGroup -resource_Group_Name_with_Alerts $alertsResourceGroup -tenant_Id $tenantId -schedule_Name $stop_Action_Name -powerShell_Runbook_Name $runbookName -automation_Account_Name $automationAccountName -subscription_Name $subscriptionName -vnet_Name $vnetName -firewall_Name $firewallName -pip_Name1 $publicIpName1 -pip_Name2 $publicIpName2 -pip_Name_Default $publicIpNameDefault -managed_Identity_Name $managedIdentityName -action "stop"

Publish-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name $runbookName -ResourceGroupName $automationResourceGroup

# Disable the schedule after creation
Set-AzAutomationSchedule -AutomationAccountName $automationAccountName -Name $start_Action_Name -IsEnabled $false -ResourceGroupName $automationResourceGroup
Set-AzAutomationSchedule -AutomationAccountName $automationAccountName -Name $stop_Action_Name  -IsEnabled $false -ResourceGroupName $automationResourceGroup

# Enable the schedule after creation
#Set-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $start_Action_Name -IsEnabled $true -ResourceGroupName $Resource_Group_Name_for_Automation
#Set-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $stop_Action_Name  -IsEnabled $true -ResourceGroupName $Resource_Group_Name_for_Automation
