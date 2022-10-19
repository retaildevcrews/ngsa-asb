param (
    [Parameter(Mandatory)]
    [String]$resource_Group_Name_with_Firewall,
    [Parameter(Mandatory)]
    [String]$resource_Group_Name_for_Automation,
    [Parameter(Mandatory)]
    [String]$automation_Account_Name,
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
    [String]$action
)



# Ensures you do not inherit an AzContext in your runbook
Write-Output "Disabling AzContext Autosave"
Disable-AzContextAutosave -Scope Process | Out-Null

# Connect using a Managed Service Identity
Write-Output "Using system-assigned managed identity"

try {
    $AzureContext = (Connect-AzAccount -Identity).context
}
catch {
    Write-Output "There is no system-assigned user identity. Aborting."; 
    exit
}

# set and store context
$AzureContext = Set-AzContext -SubscriptionName $subscription_Name -DefaultProfile $AzureContext
Write-Output "Using user-assigned managed identity"

# Connects using the Managed Service Identity of the named user-assigned managed identity
$identity = Get-AzUserAssignedIdentity -ResourceGroupName $resource_Group_Name_for_Automation -Name $managed_Identity_Name -DefaultProfile $AzureContext

# validates assignment only, not perms
if ((Get-AzAutomationAccount -ResourceGroupName $resource_Group_Name_for_Automation -Name $automation_Account_Name -DefaultProfile $AzureContext).Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId)) {
b    $AzureContext = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context

    # set and store context
    $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
}
else {
    Write-Output "Invalid or unassigned user-assigned managed identity"
    exit
}


function Stop-Firewall {

    param (
        [parameter(Mandatory = $True)]
        [String]$firewall_Name,
        [Parameter(Mandatory = $True)]
        [String]$resource_Group_Name_with_Firewall
    )

    Write-Host "Deallocating Firewall....."

    $azfw = Get-AzFirewall -Name $firewall_Name -ResourceGroupName $resource_Group_Name_with_Firewall
    $azfw.Deallocate()

    Set-AzFirewall -AzureFirewall $azfw    
}

function Restart-Firewall {

    param (
        [parameter(Mandatory = $True)]
        [String]$resource_Group_Name_with_Firewall,
        [Parameter(Mandatory = $True)]
        [String]$firewall_Name, 
        [parameter(Mandatory = $True)]
        [String]$vnet_Name,
        [Parameter(Mandatory = $True)]
        [String]$pip_Name1, 
        [parameter(Mandatory = $True)]
        [String]$pip_Name2,
        [Parameter(Mandatory = $True)]
        [String]$pip_Name_Default
    )

    Write-Host "Allocating Firewall....."

    $azfw = Get-AzFirewall -Name $firewall_Name -ResourceGroupName $resource_Group_Name_with_Firewall
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $resource_Group_Name_with_Firewall -Name $vnet_Name
    $publicip1 = Get-AzPublicIpAddress -Name $pip_Name1 -ResourceGroupName $resource_Group_Name_with_Firewall
    $publicip2 = Get-AzPublicIpAddress -Name $pip_Name2 -ResourceGroupName $resource_Group_Name_with_Firewall
    $publicip_default = Get-AzPublicIpAddress -Name $pip_Name_Default -ResourceGroupName $resource_Group_Name_with_Firewall
    $azfw.Allocate($vnet, @($publicip_default, $publicip1, $publicip2))

    Set-AzFirewall -AzureFirewall $azfw
}
function Update-Metric-Alert {

    param (
        [parameter(Mandatory = $True)]
        [String]$resource_Group_Name_with_Firewall,
        
        [Parameter(Mandatory = $True)]
        [String]$rule_Name, 

        [Parameter(Mandatory = $True)]
        [Switch]$enable_Rule
    )
   

    Get-AzMetricAlertRuleV2 -ResourceGroupName $resource_Group_Name_with_Firewall  -Name $rule_Name | Add-AzMetricAlertRuleV2 $enable_Rule
}

function Update-Log-Alert {

    param (
        [parameter(Mandatory = $True)]
        [String]$resource_Group_Name_with_Firewall,
        
        [Parameter(Mandatory = $True)]
        [String]$rule_Name, 

        [Parameter(Mandatory = $True)]
        [Switch]$enable_Rule
    )

    if ($enable_Rule) {
        Enable-AzActivityLogAlert -Name $rulrule_NameeName -ResourceGroupName $resource_Group_Name_with_Firewall
    }
    else {
        Disable-AzActivityLogAlert -Name $rule_Name -ResourceGroupName $resource_Group_Name_with_Firewall
    }
    

}

function Disable-Metric-Alerts {
    
    param (
        [parameter(Mandatory = $True)]
        [String]$resource_Group_Name_with_Firewall,
        
        [Parameter(Mandatory = $True)]
        [String]$rule_Name
    )


    Update-Metric-Alert $resource_Group_Name_with_Firewall "asb-pre-centralus-AppEndpointDown" -enable_Rule $false
    Update-Metric-Alert $resource_Group_Name_with_Firewall "asb-pre-eastus-AppEndpointDown" -enable_Rule $false
    Update-Metric-Alert $resoresource_Group_Name_with_FirewallurceGroupName "asb-pre-westus-AppEndpointDown" -enable_Rule $false

}
function Enable-Metric-Alerts {

    param (
        [parameter(Mandatory = $True)]
        [String]$resource_Group_Name_with_Firewall,
        
        [Parameter(Mandatory = $True)]
        [String]$rule_Name
    )

    Update-Metric-Alert $resource_Group_Name_with_Firewall "asb-pre-centralus-AppEndpointDown" -enable_Rule $true
    Update-Metric-Alert $resource_Group_Name_with_Firewall "asb-pre-eastus-AppEndpointDown" -enable_Rule $true
    Update-Metric-Alert $resource_Group_Name_with_Firewall "asb-pre-westus-AppEndpointDown" -enable_Rule $true
}

function Disable-Log-Alerts {
    
    param (
        [parameter(Mandatory = $True)]
        [String]$resource_Group_Name_with_Firewall)


    Update-Log-Alert $resource_Group_Name_with_Firewall "asb-dev-centralus-AppEndpointDown" -enable_Rule $false
    Update-Log-Alert $resource_Group_Name_with_Firewall "asb-dev-eastus-AppEndpointDown" -enable_Rule $false
    Update-Log-Alert $resource_Group_Name_with_Firewall "asb-dev-westus-AppEndpointDown" -enable_Rule $false

}

function Enable-Log-Alerts {
    param (
        [parameter(Mandatory = $True)]
        [String]$resourceGroupName)
    Update-Log-Alert $resource_Group_Name_with_Firewall "asb-dev-centralus-AppEndpointDown" -enable_Rule $true
    Update-Log-Alert $resource_Group_Name_with_Firewall "asb-dev-eastus-AppEndpointDown" -enable_Rule $true
    Update-Log-Alert $resource_Group_Name_with_Firewall "asb-dev-westus-AppEndpointDown" -enable_Rule $true
}

if ($action -eq "Stop") {
    Stop-Firewall $firewall_Name $resource_Group_Name_with_Firewall
    Disable-Metric-Alerts $resource_Group_Name_with_Firewall
    Disable-Log-Alerts $resource_Group_Name_with_Firewall
}
elseif ($action -eq "Start") {
    Restart-Firewall $resource_Group_Name_with_Firewall $firewall_Name $vnet_Name $pip_Name1 $pip_Name2 $pip_Name_Default
    Enable-Metric-Alerts $resource_Group_Name_with_Firewall
    Enable-Log-Alerts $resource_Group_Name_with_Firewall
}

Write-Output "Firewall Status Updated" 