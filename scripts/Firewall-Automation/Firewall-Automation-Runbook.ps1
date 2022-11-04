param (
    [Parameter(Mandatory)]
    [String]$resource_Group_Name_with_Firewall="rg-ngsa-asb-dev-hub",
    [Parameter(Mandatory)]
    [String]$resource_Group_Name_with_Alerts="rg-ngsa-asb-dev",
    [Parameter(Mandatory)]
    [String]$resource_Group_Name_for_Automation="rg-asb-firewall-automation-dev",
    [Parameter(Mandatory)]
    [String]$automation_Account_Name="aa-asb-firewall-automation-dev",
    [Parameter(Mandatory)]
    [String]$tenant_Id="72f988bf-86f1-41af-91ab-2d7cd011db47",
    [Parameter(Mandatory)]
    [String]$subscription_Name="jofultz-wcnp",
    [Parameter(Mandatory)]
    [String]$vnet_Name="vnet-eastus-hub",
    [Parameter(Mandatory)]
    [String]$firewall_Name="fw-eastus",
    [Parameter(Mandatory)]
    [String]$pip_Name1="pip-fw-eastus-01",
    [Parameter(Mandatory)]
    [String]$pip_Name2="pip-fw-eastus-02",
    [Parameter(Mandatory)]
    [String]$pip_Name_Default="pip-fw-eastus-default",
    [Parameter(Mandatory)]
    [String]$managed_Identity_Name="mi-asb-firewall-automation-dev",
    [Parameter(Mandatory)]
    [String]$action="start",
    [Parameter(Mandatory)]
    [String]$environment="dev",
    [Parameter(Mandatory)]
    [String]$location="eastus"
)

function Stop-Firewall {

    param (
        [parameter(Mandatory)]
        [String]$firewall_Name,
        [Parameter(Mandatory)]
        [String]$resource_Group_Name_with_Firewall
    )

    Write-Output "Deallocating Firewall....."

    $azfw = Get-AzFirewall -Name $firewall_Name -ResourceGroupName $resource_Group_Name_with_Firewall
    $azfw.Deallocate()

    Set-AzFirewall -AzureFirewall $azfw    
}

function Restart-Firewall {

    param (
        [parameter(Mandatory)]
        [String]$resource_Group_Name_with_Firewall,
        [Parameter(Mandatory)]
        [String]$firewall_Name, 
        [parameter(Mandatory)]
        [String]$vnet_Name,
        [Parameter(Mandatory)]
        [String]$pip_Name1, 
        [parameter(Mandatory)]
        [String]$pip_Name2,
        [Parameter(Mandatory)]
        [String]$pip_Name_Default
    )

    Write-Output "Allocating Firewall....."

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
        [parameter(Mandatory)]
        [String]$resource_Group_Name_with_Alerts,
        
        [Parameter(Mandatory)]
        [String]$rule_Name, 

        [Parameter(Mandatory)]
        [Switch]$enable_Rule
    )
   
    Write-Output "Update-Metric-Alert Rule Name: $rule_Name"
    try{
        Get-AzMetricAlertRuleV2 -ResourceGroupName $resource_Group_Name_with_Alerts -Name $rule_Name | Add-AzMetricAlertRuleV2 -DisableRule:$enable_Rule -ErrorAction SilentlyContinue
    }
    catch{
        Write-Output "Issue with $rule_Name in $resource_Group_Name_with_Alerts and it is enable: $enable_Rule"
    }
}

function Update-Log-Alert {

    param (
        [parameter(Mandatory)]
        [String]$resource_Group_Name_with_Alerts,
        
        [Parameter(Mandatory)]
        [String]$rule_Name, 

        [Parameter(Mandatory)]
        [Switch]$enable_Rule
    )

    $obj = $null
    Write-Output "Rule: $rule_Name Group: $resource_Group_Name_with_Alerts"
    try{
        $obj = Get-AzActivityLogAlert -ResourceGroupName $resource_Group_Name_with_Alerts -Name $rule_Name -ErrorAction SilentlyContinue
    }
    catch{
        Write-Output "$rule_Name was not found"
    }

    if ($enable_Rule) {
        Write-Output "Update-Log-Alert: Enable:$enable_Rule Rule Name: $rule_Name"
        if($null -ne $obj){
            Enable-AzActivityLogAlert -InputObject $obj
        }

    }
    else {
        Write-Output "Update-Log-Alert: Enable:$enable_Rule Rule Name: $rule_Name"
        if($null -ne $obj){
            Disable-AzActivityLogAlert -InputObject $obj
        }
    }
}

function Disable-Metric-Alerts {
    
    param (
        [parameter(Mandatory)]
        [String]$resource_Group_Name_with_Alerts,

        [Parameter(Mandatory)]
        [String]$rule_Name,

        [Parameter(Mandatory)]
        [String]$environment,

        [Parameter(Mandatory)]
        [String]$location

    )
    Write-Output "Disable-Metric-Alerts Rule Name: $rule_Name"
    Update-Metric-Alert -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -rule_Name $rule_Name

}

function Enable-Metric-Alerts {

    param (
        [parameter(Mandatory)]
        [String]$resource_Group_Name_with_Alerts,

        [Parameter(Mandatory)]
        [String]$rule_Name,

        [Parameter(Mandatory)]
        [String]$environment,

        [Parameter(Mandatory)]
        [String]$location
    )
    Write-Output "Enable-Metric-Alerts Rule Name: $rule_Name"
    Update-Metric-Alert -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -rule_Name $rule_Name -enable_Rule
}

function Disable-Log-Alerts {
    
    param (
        [parameter(Mandatory)]
        [String]$resource_Group_Name_with_Alerts
    )

    Update-Log-Alert -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -rule_Name "NGSA-Client-FailedRequests"
    Update-Log-Alert -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -rule_Name "NGSA-Client-TooFewRequests"
    Update-Log-Alert -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -rule_Name "NGSA-Server-FailedRequests"
    Update-Log-Alert -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -rule_Name "NGSA-Server-TooFewRequests"
    Update-Log-Alert -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -rule_Name "NGSA-Server-TooManyRequests"
}

function Enable-Log-Alerts {
    
    param (
        [parameter(Mandatory)]
        [String]$resource_Group_Name_with_Alerts
    )
    
    Update-Log-Alert -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -rule_Name "NGSA-Client-FailedRequests" -enable_Rule
    Update-Log-Alert -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -rule_Name "NGSA-Client-TooFewRequests" -enable_Rule
    Update-Log-Alert -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -rule_Name "NGSA-Server-FailedRequests" -enable_Rule
    Update-Log-Alert -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -rule_Name "NGSA-Server-TooFewRequests" -enable_Rule
    Update-Log-Alert -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -rule_Name "NGSA-Server-TooManyRequests" -enable_Rule
}



    # Ensures you do not inherit an AzContext in your runbook
    Write-Output "Disabling AzContext Autosave"
    Disable-AzContextAutosave -Scope Process | Out-Null

    $identity = Get-AzUserAssignedIdentity -ResourceGroupName $resource_Group_Name_for_Automation -Name $managed_Identity_Name
    Connect-AzAccount -Identity -AccountId $identity.Id
    $AzureContext = Set-AzContext -SubscriptionName $subscription_Name -Tenant $tenant_Id
    Write-Output "Using user-assigned managed identity"

    # Connects using the Managed Service Identity of the named user-assigned managed identity
    $identity = Get-AzUserAssignedIdentity -ResourceGroupName $resource_Group_Name_for_Automation -Name $managed_Identity_Name -DefaultProfile $AzureContext

    # validates assignment only, not perms
    if ((Get-AzAutomationAccount -ResourceGroupName $resource_Group_Name_for_Automation -Name $automation_Account_Name -DefaultProfile $AzureContext).Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId)) {
        $AzureContext = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context

        # set and store context
        $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
    }
    else {
       Write-Output "Invalid or unassigned user-assigned managed identity"
        exit
    }


    $dynamic_Rule_Name="asb-" + $environment + "-" + $location + "-AppEndpointDown"
    
    if ($action.ToLower() -eq "stop") {
        Stop-Firewall -resource_Group_Name_with_Firewall $resource_Group_Name_with_Firewall -firewall_Name $firewall_Name
       
        Disable-Metric-Alerts -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -location $location -environment $environment -rule_Name $dynamic_Rule_Name
        Disable-Log-Alerts -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts
    }
    
    elseif ($action.ToLower() -eq "start") {
        Restart-Firewall -resource_Group_Name_with_Firewall $resource_Group_Name_with_Firewall -firewall_Name $firewall_Name -vnet_Name $vnet_Name -pip_Name1 $pip_Name1 -pip_Name2 $pip_Name2 -pip_Name_Default $pip_Name_Default
                
        Enable-Metric-Alerts -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts -location $location -environment $environment -rule_Name $dynamic_Rule_Name
        Enable-Log-Alerts -resource_Group_Name_with_Alerts $resource_Group_Name_with_Alerts
    }

   Write-Output "Firewall Status Updated"
   return $LASTEXITCODE
   