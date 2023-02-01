param(
    [Parameter(Mandatory)]
    [String]$tenantId,
    [Parameter(Mandatory)]
    [String]$subscriptionName,
    [Parameter(Mandatory)]
    [String]$resourceGroup,
    [Parameter(Mandatory)]
    [String]$resourceName,
    [Parameter(Mandatory)]
    [String]$automationAccountResourceGroup,
    [Parameter(Mandatory)]
    [String]$automationAccountName,
    [Parameter(Mandatory)]
    [String]$managedIdentityName,
    [Parameter(Mandatory)]
    [String]$operation,
    [Parameter(Mandatory)]
    [String]$resourceType
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

Write-Output "Starting "$resourceType" "$resourceName
$operation=$operation.ToLower()
switch($resourceType.ToLower())
{
    "akscluster"{
        if($operation -eq "start"){
            Start-AzAksCluster -Name $resourceName -ResourceGroupName $resourceGroup
         } elseif($operation -eq "stop"){
            Stop-AzAksCluster -Name $resourceName -ResourceGroupName $resourceGroup
         } else {
            Write-Output "Invalid operation"
         }
    }
    "applicationgateway"{
        $appGateway = Get-AzApplicationGateway -Name $resourcename -ResourceGroupName $resourceGroup
        if($operation -eq "start"){
            Start-AzApplicationGateway -ApplicationGateway $appGateway
         } elseif($operation -eq "stop"){
            Stop-AzApplicationGateway -ApplicationGateway $appGateway
         } else {
            Write-Output "Invalid operation"
         }
    }
    Default {
        Write-Output "$resourceType Not supported"
    }
}


Write-Output "$resourceType $resourceName Started"
return $LASTEXITCODE
