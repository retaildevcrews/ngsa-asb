param (
    [Parameter(Mandatory)]
    [String]$spclientid,
    [Parameter(Mandatory)]
    [String]$spsecret,
    [Parameter(Mandatory)]
    [String]$runbookName
)

foreach ($line in (Get-Content -Path './scripts/App-Gateway-Automation/App-Gateway-Automation-Infrastructure-Variables.env')) {
  if ($line.Contains('export ')) {
    $line = $line.Trim()
    $line = $line -replace 'export ', ''
    $line = $line.Replace("'", "")
    $lineItems = $line -split '='
    [System.Environment]::SetEnvironmentVariable( $lineItems[0], $lineItems[1] )
  }
}

$tenantId = $env:ASB_AGW_Tenant_Id
$subscriptionName = $env:ASB_AGW_Subscription_Name
$baseName = $env:ASB_AGW_Deployment_Name
$environment = $env:ASB_AGW_Environment
$location = $env:ASB_AGW_Location

$automationResourceGroup = $env:ASB_AGW_Automation_Account_Resource_Group
$appGatewayResourceGroup = $env:ASB_AGW_App_Gateway_Resource_Group
$automationAccountName = $env:ASB_AGW_Automation_Account_Name
$appGatewayName = $env:ASB_AGW_App_Gateway_Name

$managedIdentityName = $env:ASB_AGW_UAMI_Name
$baseScheduleName = "as-" + $baseName + "-agw-automation-" + $location + "-" + $environment


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
  
  New-AzAutomationSchedule -AutomationAccountName $automation_Account_Name -Name $schedule_Name -StartTime $start_Time -ExpiryTime $end_Time -DayInterval 1 -ResourceGroupName $resource_Group_Name_for_Automation
  
  Write-Host "Completed creating new Azure Automation Schedule."

}

# Links the Runbook and Schedule
function Edit-ScheduleAndRunbook {

  param (
    [Parameter(Mandatory)]
    [String]$resource_Group_Name_for_App_Gateway,

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
    [String]$subscription_Name,
      
    [Parameter(Mandatory)]
    [String]$app_Gateway_Name,
      
    [Parameter(Mandatory)]
    [String]$managed_Identity_Name,
      
    [Parameter(Mandatory)]
    [String]$enable

  )

  Write-Host "Registering an Azure Automation Schedule to a Automation Runbook..."
  $error.Clear()

  $params = @{}
  $params.Add("resource_Group_Name_for_App_Gateway", "$resource_Group_Name_for_App_Gateway")
  $params.Add("app_Gateway_Name", "$app_Gateway_Name")
  $params.Add("enable", "$enable")
  $params.Add("resource_Group_Name_for_Automation", "$resource_Group_Name_for_Automation") 
  $params.Add("automation_Account_Name", "$automation_Account_Name")  
  $params.Add("tenant_Id", "$tenant_Id")
  $params.Add("subscription_Name", "$subscription_Name")
  $params.Add("managed_Identity_Name", "$managed_Identity_Name")

  Register-AzAutomationScheduledRunbook -ResourceGroupName $resource_Group_Name_for_Automation -AutomationAccountName $automation_Account_Name -RunbookName $powerShell_Runbook_Name -ScheduleName $schedule_Name -Parameters $params
  
  Write-Host "Completed registering an Azure Automation Schedule to an Automation Runbook."
}

function Authenticate {  
  
  $password=ConvertTo-SecureString $spsecret -AsPlainText -Force

  $Credential=New-Object -TypeName System.Management.Automation.PSCredential ($spclientid, $password)
  
  try{
    Connect-AzAccount -ServicePrincipal -Tenant $tenantId -Subscription $subscriptionName -Credential $Credential
    Write-Host "Successfully connected to Azure account."
  }
  catch{
    Write-Host "Unexpected error occurred when trying to connect to Azure account."
  }

  Set-AzContext -Subscription $subscriptionName
}

$start_Time = (Get-Date "06:00:00").AddHours(+4).AddDays(1)
$end_Time = (Get-Date $start_Time).AddYears(3)

Authenticate -Subscription_Name $subscriptionName

$start_Action_Name = $baseScheduleName + "-start"

New-Schedule -automation_Account_Name $automationAccountName -resource_Group_Name_for_Automation $automationResourceGroup -schedule_Name $start_Action_Name -start_Time $start_Time -end_Time $end_Time

Edit-ScheduleAndRunbook -resource_Group_Name_for_App_Gateway $appGatewayResourceGroup -resource_Group_Name_for_Automation $automationResourceGroup -tenant_Id $tenantId -schedule_Name $start_Action_Name -powerShell_Runbook_Name $runbookName -automation_Account_Name $automationAccountName -subscription_Name $subscriptionName -app_Gateway_Name $appGatewayName -managed_Identity_Name $managedIdentityName -enable $true

# Disable the schedule after creation
Set-AzAutomationSchedule -AutomationAccountName $automationAccountName -Name $start_Action_Name -IsEnabled $false -ResourceGroupName $automationResourceGroup

# Enable the schedule after creation
#Set-AzAutomationSchedule -AutomationAccountName $Automation_Account_Name -Name $start_Action_Name -IsEnabled $true -ResourceGroupName $Resource_Group_Name_for_Automation
