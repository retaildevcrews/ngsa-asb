Param(
    [Parameter(Mandatory)]
    [String]$resourceGroupName,

    [Parameter(Mandatory)]
    [String]$automationAccount,

    [Parameter(Mandatory)]
    [String]$subscriptionName,

    [Parameter(Mandatory)]
    [String]$vnetName,
    
    [Parameter(Mandatory)]
    [String]$fw_name,
    
    [Parameter(Mandatory)]
    [String]$pip_name1,
    
    [Parameter(Mandatory)]
    [String]$pip_name2,
    
    [Parameter(Mandatory)]
    [String]$pip_name_default,
    
    [Parameter(Mandatory = $True)]
    [String]$UAMI,
    
    [Parameter(Mandatory = $True)]
    [String]$update
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
$AzureContext = Set-AzContext -SubscriptionName $subscriptionName -DefaultProfile $AzureContext
Write-Output "Using user-assigned managed identity"

# Connects using the Managed Service Identity of the named user-assigned managed identity
$identity = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $UAMI -DefaultProfile $AzureContext

# validates assignment only, not perms
if ((Get-AzAutomationAccount -ResourceGroupName $resourceGroupName -Name $automationAccount -DefaultProfile $AzureContext).Identity.UserAssignedIdentities.Values.PrincipalId.Contains($identity.PrincipalId)) {
    $AzureContext = (Connect-AzAccount -Identity -AccountId $identity.ClientId).context

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
        [String]$fw_name,
        [Parameter(Mandatory = $True)]
        [String]$resourceGroupName
    )

    Write-Host "Deallocating Firewall....."

    $azfw = Get-AzFirewall -Name $fw_name -ResourceGroupName $resourceGroupName
    $azfw.Deallocate()

    Set-AzFirewall -AzureFirewall $azfw    
}

function Restart-Firewall {

    param (
        [parameter(Mandatory = $True)]
        [String]$resourceGroupName,
        [Parameter(Mandatory = $True)]
        [String]$fw_name, 
        [parameter(Mandatory = $True)]
        [String]$vnetName,
        [Parameter(Mandatory = $True)]
        [String]$pip_name1, 
        [parameter(Mandatory = $True)]
        [String]$pip_name2,
        [Parameter(Mandatory = $True)]
        [String]$pip_name_default
    )

    Write-Host "Allocating Firewall....."

    $azfw = Get-AzFirewall -Name $fw_name -ResourceGroupName $resourceGroupName
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName
    $publicip1 = Get-AzPublicIpAddress -Name $pip_name1 -ResourceGroupName $resourceGroupName
    $publicip2 = Get-AzPublicIpAddress -Name $pip_name2 -ResourceGroupName $resourceGroupName
    $publicip_default = Get-AzPublicIpAddress -Name $pip_name_default -ResourceGroupName $resourceGroupName
    $azfw.Allocate($vnet, @($publicip_default, $publicip1, $publicip2))

    Set-AzFirewall -AzureFirewall $azfw
}


if ($update -eq "Stop") {
    Stop-Firewall $fw_name $resourceGroupName
}
elseif ($update -eq "Start") {
    Restart-Firewall $resourceGroupName $fw_name $vnetName $pip_name1 $pip_name2 $pip_name_default
}

Write-Output "Firewall Status Updated" 

# ToDo: Remove and add alerts as appropriate