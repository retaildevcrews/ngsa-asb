Param(
    [Parameter(Mandatory)]
    [String]$automationResourceGroupName,

    [Parameter(Mandatory)]
    [String]$firewallResourceGroupName,

    [Parameter(Mandatory)]
    [String]$automationAccount,

    [Parameter(Mandatory)]
    [String]$subscriptionName,

    [Parameter(Mandatory)]
    [String]$powerShellRunbookName,

    [Parameter(Mandatory)]
    [String]$subscriptionId,

    [Parameter(Mandatory)]
    [String]$tenantId,

    [Parameter(Mandatory)]
    [String]$vnetName,
    
    [Parameter(Mandatory)]
    [String]$firewallName,
    
    [Parameter(Mandatory)]
    [String]$pipName01,
    
    [Parameter(Mandatory)]
    [String]$pipName02,
    
    [Parameter(Mandatory)]
    [String]$pipNameDefault,
    
    [Parameter(Mandatory = $True)]
    [String]$identityName,

    [Parameter(Mandatory)]
    [String]$baseScheduleName,

    [Parameter(Mandatory)]
    [String]$asb_Environment
)


function New-Schedule {

  param (
      [parameter(Mandatory = $True)]
      [String]$AutomationAccountName,
      
      [parameter(Mandatory = $True)]
      [String]$AutomationResourceGroupName,
      
      [Parameter(Mandatory = $True)]
      [String]$ScheduleName,
      
      [Parameter(Mandatory = $True)]
      [String]$StartTime,
      
      [Parameter(Mandatory = $True)]
      [String]$EndTime
  )

  Write-Host "Creating new Azure Automation Schedule..."
  New-AzAutomationSchedule -AutomationAccountName $AutomationAccountName -Name $ScheduleName -StartTime $StartTime -ExpiryTime $EndTime -DayInterval 1 -ResourceGroupName $AutomationResourceGroupName
  Write-Host "Completed creating new Azure Automation Schedule."
}

function Link-ScheduleAndRunbook {

  param (
      [parameter(Mandatory = $True)]
      [String]$AutomationResourceGroupName,
      
      [Parameter(Mandatory = $True)]
      [String]$ScheduleName,

      [Parameter(Mandatory = $True)]
      [String]$PowerShellRunbookName,

      [Parameter(Mandatory = $True)]
      [String]$resourceGroupName,
      
      [Parameter(Mandatory = $True)]
      [String]$automationAccount,
      
      [Parameter(Mandatory = $True)]
      [String]$subscriptionName,
      
      [Parameter(Mandatory = $True)]
      [String]$vnetName,
      
      [Parameter(Mandatory = $True)]
      [String]$firewallName,
      
      [Parameter(Mandatory = $True)]
      [String]$pipName01,
      
      [Parameter(Mandatory = $True)]
      [String]$pipName02,
      
      [Parameter(Mandatory = $True)]
      [String]$pipNameDefault,
      
      [Parameter(Mandatory = $True)]
      [String]$UAMI,
      
      [Parameter(Mandatory = $True)]
      [String]$update

  )

  Write-Host "Registering an Azure Automation Schedule to a Automation Runbook..."
  Write-Host $automationAccount
  Write-Host $PowerShellRunbookName
  Write-Host $ScheduleName
  Write-Host $AutomationResourceGroupName
  write-Host $resourceGroupName
  Write-Host $automationAccount
  Write-Host $subscriptionName
  Write-Host $vnetName
  Write-Host $firewallName
  Write-Host $pipName01
  Write-Host $pipName02
  Write-Host $pipNameDefault
  Write-Host $UAMI
  Write-Host $update

  Register-AzAutomationScheduledRunbook -AutomationAccountName $automationAccount -RunbookName $PowerShellRunbookName -ScheduleName $ScheduleName -ResourceGroupName $AutomationResourceGroupName -Parameters @{"resourceGroupName"="$resourceGroupName";"automationAccount"="$automationAccount";"subscriptionName"="$subscriptionName";"vnetName"="$vnetName";"firewallName"="$firewallName";"pipName01"="$pipName01";"pipName02"="$pipName02";"pipNameDefault"="$pipNameDefault";"UAMI"="$UAMI";"update"="$update"}
  Write-Host "Completed registering an Azure Automation Schedule to a Automation Runbook."
}



Connect-AzAccount -UseDeviceAuth
Select-AzSubscription -SubscriptionId $subscriptionId

$StopTime = (Get-Date "21:00:00").AddDays(1)
$StartTime = (Get-Date "06:00:00").AddDays(1)
$EndTime = $StartTime.AddYears(3)

$name = $baseScheduleName + "-" + $asb_Environment + "-"
$startName = $name + "start"
$stopName = $name + "stop"
New-Schedule -AutomationAccountName $automationAccount -AutomationResourceGroupName $automationResourceGroupName  -ScheduleName $startName -StartTime $StartTime -EndTime $EndTime
New-Schedule -AutomationAccountName $automationAccount -AutomationResourceGroupName $automationResourceGroupName  -ScheduleName $stopName -StartTime $StopTime -EndTime $EndTime

Link-ScheduleAndRunbook -AutomationResourceGroupName $automationResourceGroupName -ScheduleName $startName -PowerShellRunbookName $powerShellRunbookName -resourceGroupName $FirewallResourceGroupName -automationAccount $automationAccount -subscriptionName $subscriptionName -vnetName $vnetName -firewallName $FirewallName -pipName01 $PIPName01 -pipName02 $PIPName02 -pipNameDefault $PIPNameDefault -UAMI $identityName -update "start"
Link-ScheduleAndRunbook -AutomationResourceGroupName $automationResourceGroupName -ScheduleName $stopName -PowerShellRunbookName $powerShellRunbookName -resourceGroupName $FirewallResourceGroupName -automationAccount $automationAccount -subscriptionName $subscriptionName -vnetName $vnetName -firewallName $FirewallName -pipName01 $PIPName01 -pipName02 $PIPName02 -pipNameDefault $PIPNameDefault -UAMI $identityName -update "stop"

#Disable the schedule after creation
# Set-AzAutomationSchedule -AutomationAccountName $automationAccount -Name $name -IsEnabled $false -ResourceGroupName $automationResourceGroupName
# Set-AzAutomationSchedule -AutomationAccountName $automationAccount -Name $name  -IsEnabled $false -ResourceGroupName $automationResourceGroupName

#Enable the schedule after creation
