param(
    [Parameter(Mandatory)]
    [String]$resource_Group_Name_for_AKS_Cluster,
    [Parameter(Mandatory)]
    [String]$aks_Cluster_Name,
    [Parameter(Mandatory)]
    [Boolean]$enable,
    [Parameter(Mandatory)]
    [String]$resource_Group_Name_for_Automation,
    [Parameter(Mandatory)]
    [String]$automation_Account_Name,
    [Parameter(Mandatory)]
    [String]$tenant_Id,
    [Parameter(Mandatory)]
    [String]$subscription_Name,
    [Parameter(Mandatory)]
    [String]$managed_Identity_Name
)



# Ensures you do not inherit an AzContext in your runbook
Write-Output "Disabling AzContext Autosave"
Disable-AzContextAutosave -Scope Process | Out-Null

# Connect using a Managed Service Identity
Write-Output "Using system-assigned managed identity"

Connect-AzAccount -Identity

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

$aksClusterId = (Get-AzAksCluster -Name $aks_Cluster_Name -ResourceGroupName $resource_Group_Name_for_AKS_Cluster).Id
$aksCluster = Get-AzResource -ResourceId $aksClusterId

Write-Output $aksCluster.Properties.powerState.code

if ($enable -eq $true) {
    Write-Output "Starting the aks cluster."
    Start-AzAksCluster -Name $aks_Cluster_Name -ResourceGroupName $resource_Group_Name_for_AKS_Cluster
}
if ($enable -eq $false) {
    Write-Output "Stopping the aks cluster."
    Stop-AzAksCluster -Name $aks_Cluster_Name -ResourceGroupName $resource_Group_Name_for_AKS_Cluster
}

Write-Output "AKS Cluster Status Updated"
return $LASTEXITCODE
