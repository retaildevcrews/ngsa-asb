param (
    [Parameter(Mandatory)]
    [String]$tenantId,
    [Parameter(Mandatory)]
    [String]$subscriptionName,
    [Parameter(Mandatory)]
    [String]$automationAccountResourceGroup,
    [Parameter(Mandatory)]
    [String]$automationAccountName,
    [Parameter(Mandatory)]
    [String]$managedIdentityName,
    [Parameter(Mandatory)]
    [String]$operation,
    [Parameter(Mandatory)]
    [String]$fwResourceGroup,
    [Parameter(Mandatory)]
    [String]$alertsResourceGroup,
    [Parameter(Mandatory)]
    [String]$vnetName,
    [Parameter(Mandatory)]
    [String]$fwName,
    [Parameter(Mandatory)]
    [String]$pipName1,
    [Parameter(Mandatory)]
    [String]$pipName2,
    [Parameter(Mandatory)]
    [String]$pipNameDefault,
    [Parameter(Mandatory)]
    [String]$environment,
    [Parameter(Mandatory)]
    [String]$location
)

function Stop-Firewall {

    param (
        [parameter(Mandatory)]
        [String]$fwName,
        [Parameter(Mandatory)]
        [String]$fwResourceGroup
    )

    Write-Output "Deallocating Firewall....."

    $azfw = Get-AzFirewall -Name $fwName -ResourceGroupName $fwResourceGroup
    $azfw.Deallocate()

    Set-AzFirewall -AzureFirewall $azfw    
}

function Restart-Firewall {

    param (
        [parameter(Mandatory)]
        [String]$fwResourceGroup,
        [Parameter(Mandatory)]
        [String]$fwName, 
        [parameter(Mandatory)]
        [String]$vnetName,
        [Parameter(Mandatory)]
        [String]$pipName1, 
        [parameter(Mandatory)]
        [String]$pipName2,
        [Parameter(Mandatory)]
        [String]$pipNameDefault
    )

    Write-Output "Allocating Firewall....."

    $azfw = Get-AzFirewall -Name $fwName -ResourceGroupName $fwResourceGroup
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $fwResourceGroup -Name $vnetName
    $publicip1 = Get-AzPublicIpAddress -Name $pipName1 -ResourceGroupName $fwResourceGroup
    $publicip2 = Get-AzPublicIpAddress -Name $pipName2 -ResourceGroupName $fwResourceGroup
    $publicip_default = Get-AzPublicIpAddress -Name $pipNameDefault -ResourceGroupName $fwResourceGroup
    $azfw.Allocate($vnet, @($publicip_default, $publicip1, $publicip2))

    Set-AzFirewall -AzureFirewall $azfw
}

function Update-Metric-Alert {

    param (
        [parameter(Mandatory)]
        [String]$alertsResourceGroup,
        
        [Parameter(Mandatory)]
        [String]$rule_Name, 

        #This cannot be Mandatory because is a Switch type
        [Switch]$enable_Rule
    )
   
    Write-Output "Update-Metric-Alert Rule Name: $rule_Name"
    try{
        Get-AzMetricAlertRuleV2 -ResourceGroupName $alertsResourceGroup -Name $rule_Name | Add-AzMetricAlertRuleV2 -DisableRule:$enable_Rule -ErrorAction SilentlyContinue
    }
    catch{
        Write-Output "Issue with $rule_Name in $alertsResourceGroup and it is enable: $enable_Rule"
    }
}

function Update-Log-Alert {

    param (
        [parameter(Mandatory)]
        [String]$alertsResourceGroup,
        
        [Parameter(Mandatory)]
        [String]$rule_Name, 

        #This cannot be Mandatory because is a Switch type
        [Switch]$enable_Rule
    )

    $obj = $null
    Write-Output "Rule: $rule_Name Group: $alertsResourceGroup"
    try{
        $obj = Get-AzActivityLogAlert -ResourceGroupName $alertsResourceGroup -Name $rule_Name -ErrorAction SilentlyContinue
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
        [String]$alertsResourceGroup,

        [Parameter(Mandatory)]
        [String]$rule_Name,

        [Parameter(Mandatory)]
        [String]$environment,

        [Parameter(Mandatory)]
        [String]$location

    )
    Write-Output "Disable-Metric-Alerts Rule Name: $rule_Name"
    Update-Metric-Alert -alertsResourceGroup $alertsResourceGroup -rule_Name $rule_Name

}

function Enable-Metric-Alerts {

    param (
        [parameter(Mandatory)]
        [String]$alertsResourceGroup,

        [Parameter(Mandatory)]
        [String]$rule_Name,

        [Parameter(Mandatory)]
        [String]$environment,

        [Parameter(Mandatory)]
        [String]$location
    )
    Write-Output "Enable-Metric-Alerts Rule Name: $rule_Name"
    Update-Metric-Alert -alertsResourceGroup $alertsResourceGroup -rule_Name $rule_Name -enable_Rule
}

function Disable-Log-Alerts {
    
    param (
        [parameter(Mandatory)]
        [String]$alertsResourceGroup
    )

    Update-Log-Alert -alertsResourceGroup $alertsResourceGroup -rule_Name "NGSA-Client-FailedRequests"
    Update-Log-Alert -alertsResourceGroup $alertsResourceGroup -rule_Name "NGSA-Client-TooFewRequests"
    Update-Log-Alert -alertsResourceGroup $alertsResourceGroup -rule_Name "NGSA-Server-FailedRequests"
    Update-Log-Alert -alertsResourceGroup $alertsResourceGroup -rule_Name "NGSA-Server-TooFewRequests"
    Update-Log-Alert -alertsResourceGroup $alertsResourceGroup -rule_Name "NGSA-Server-TooManyRequests"
}

function Enable-Log-Alerts {
    
    param (
        [parameter(Mandatory)]
        [String]$alertsResourceGroup
    )
    
    Update-Log-Alert -alertsResourceGroup $alertsResourceGroup -rule_Name "NGSA-Client-FailedRequests" -enable_Rule
    Update-Log-Alert -alertsResourceGroup $alertsResourceGroup -rule_Name "NGSA-Client-TooFewRequests" -enable_Rule
    Update-Log-Alert -alertsResourceGroup $alertsResourceGroup -rule_Name "NGSA-Server-FailedRequests" -enable_Rule
    Update-Log-Alert -alertsResourceGroup $alertsResourceGroup -rule_Name "NGSA-Server-TooFewRequests" -enable_Rule
    Update-Log-Alert -alertsResourceGroup $alertsResourceGroup -rule_Name "NGSA-Server-TooManyRequests" -enable_Rule
}

    # Ensures you do not inherit an AzContext in your runbook
    Write-Output "Disabling AzContext Autosave"
    Disable-AzContextAutosave -Scope Process | Out-Null
    
	# Connect using a Managed Service Identity
    Write-Output "Using system-assigned managed identity"
	
	Connect-AzAccount -Identity
	
	$identity = Get-AzUserAssignedIdentity -ResourceGroupName $automationAccountResourceGroup -Name $managedIdentityName

    Connect-AzAccount -Identity -AccountId $identity.Id

    $AzureContext = Set-AzContext -SubscriptionName $subscriptionName -Tenant $tenantId
    Write-Output "Using user-assigned managed identity"

    # Connects using the Managed Service Identity of the named user-assigned managed identity
    $identity = Get-AzUserAssignedIdentity -ResourceGroupName $automationAccountResourceGroup -Name $managedIdentityName -DefaultProfile $AzureContext

    # validates assignment only, not perms
    if ((Get-AzAutomationAccount -ResourceGroupName $automationAccountResourceGroup -Name $automationAccountName -DefaultProfile $AzureContext).Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId)) {
        $AzureContext = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context

        # set and store context
        $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
    }
    else {
       Write-Output "Invalid or unassigned user-assigned managed identity"
        exit
    }


    $dynamic_Rule_Name="asb-" + $environment + "-" + $location + "-AppEndpointDown"
    
    if ($operation.ToLower() -eq "stop") {
        Stop-Firewall -resourceGroup $fwResourceGroup -fwName $fwName
       
        Disable-Metric-Alerts -alertsResourceGroup $alertsResourceGroup -location $location -environment $environment -rule_Name $dynamic_Rule_Name
        Disable-Log-Alerts -alertsResourceGroup $alertsResourceGroup
    }
    
    elseif ($operation.ToLower() -eq "start") {
        Restart-Firewall -resourceGroup $fwResourceGroup -fwName $fwName -vnetName $vnetName -pipName1 $pipName1 -pipName2 $pipName2 -pipNameDefault $pipNameDefault
                
        Enable-Metric-Alerts -alertsResourceGroup $alertsResourceGroup -location $location -environment $environment -rule_Name $dynamic_Rule_Name
        Enable-Log-Alerts -alertsResourceGroup $alertsResourceGroup
    }

   Write-Output "Firewall Status Updated"
   return $LASTEXITCODE
