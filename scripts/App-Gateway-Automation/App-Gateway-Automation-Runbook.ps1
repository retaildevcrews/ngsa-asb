param(
    [Parameter(Mandatory)]
    [String]$resource_Group_Name_for_App_Gateway,
    [Parameter(Mandatory)]
    [String]$app_Gateway_Name,
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

$appGateway = Get-AzApplicationGateway -Name $app_Gateway_Name -ResourceGroupName $resource_Group_Name_for_App_Gateway

if ($enable -eq $true -and $appGateway.OperationalState -eq "Stopped") {
    Write-Output "Starting the application gateway."
    Start-AzApplicationGateway -ApplicationGateway $appGateway
}
if ($enable -eq $false -and $appGateway.OperationalState -eq "Running") {
    Write-Output "Stopping the application gateway."
    Stop-AzApplicationGateway -ApplicationGateway $appGateway
}

Write-Output "Application Gateway Status Updated"
return $LASTEXITCODE
