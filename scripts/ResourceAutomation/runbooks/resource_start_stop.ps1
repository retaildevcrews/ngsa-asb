param(
    [Parameter(Mandatory)]
    [String]$tenantId,
    [Parameter(Mandatory)]
    [String]$subscriptionName,
    [Parameter(Mandatory)]
    [String]$resourceGroup,
    [Parameter(Mandatory)]
    [String]$clusterName,
    [Parameter(Mandatory)]
    [String]$gatewayName,
    [Parameter(Mandatory)]
    [String]$automationAccountResourceGroup,
    [Parameter(Mandatory)]
    [String]$automationAccountName,
    [Parameter(Mandatory)]
    [String]$managedIdentityName,
    [Parameter(Mandatory)]
    [String]$operation
)

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

Write-Output "Starting $resourceType and $resourceName"
switch($operation.ToLower())
{
    "start"{
        $appGateway = Get-AzApplicationGateway -Name $gatewayName -ResourceGroupName $resourceGroup
        Start-AzApplicationGateway -ApplicationGateway $appGateway
        Start-AzAksCluster -Name $clusterName -ResourceGroupName $resourceGroup
    }
    "stop"{
        Stop-AzAksCluster -Name $clusterName -ResourceGroupName $resourceGroup
        $appGateway = Get-AzApplicationGateway -Name $gatewayName -ResourceGroupName $resourceGroup
        Stop-AzApplicationGateway -ApplicationGateway $appGateway
    }
    Default {
        Write-Output "Invalid Operation, supported operations are start and stop"
    }
}

Write-Output "Operation $operation $resourceType $resourceName completed."
return $LASTEXITCODE
