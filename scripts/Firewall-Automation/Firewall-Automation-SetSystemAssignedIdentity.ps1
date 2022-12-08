param (

    [Parameter(Mandatory)]
    [String]$susbcription_Id="PLACE_HOLDER",
    [Parameter(Mandatory)]
    [String]$resourcegroup_Name="PLACE_HOLDER",
    [Parameter(Mandatory)]
    [String]$managed_identity_Name="PLACE_HOLDER",
    [Parameter(Mandatory)]
    [String]$automation_account_Name="PLACE_HOLDER"
)

foreach ($line in (Get-Content -Path './scripts/Firewall-Automation/Firewall-Automation-Infrastructure-Variables.env')) {
    if ($line.Contains('export ')) {
      $line = $line -replace 'export ', ''
      $line = $line.Replace("'", "")
      $lineItems = $line -split '='
      [System.Environment]::SetEnvironmentVariable( $lineItems[0], $lineItems[1] )
    }
  }
  
$tenantId = $env:ASB_FW_Tenant_Id
$subscriptionName = $env:ASB_FW_Subscription_Name
$spclientid = $env:ASB_SP_CONNECT_AZ_CLIENTID
$spsecret = $env:ASB_SP_CONNECT_AZ_SECRET

# NOTE : do not want to write since this will output secret 
# Write-Output((Get-ChildItem env:*).GetEnumerator() | Sort-Object Name | Out-String)
 

$password=ConvertTo-SecureString $spsecret -AsPlainText -Force

$Credential=New-Object -TypeName System.Management.Automation.PSCredential ($spclientid, $password)

try{
    Connect-AzAccount -ServicePrincipal -Tenant $tenantId -Subscription $subscriptionName -Credential $Credential
    Write-Host "Successfully connected to Azure account."
}
catch{
    Write-Host "Unexpected error occurred when trying to connect to Azure account."
}

  
# NOTE: this command requies that SP must be a member of the followinf Subscription azure roles
# -Automation Contributor
# -Managed Identity Operator
  
$assignUserIdentity = "/subscriptions/$susbcription_Id/resourcegroups/$resourcegroup_Name/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$managed_identity_Name";

Write-Host "Target assignUserIdentity resource: " $assignUserIdentity

try{
    Set-AzAutomationAccount -AssignUserIdentity $assignUserIdentity -ResourceGroupName $resourcegroup_Name -Name $automation_account_Name -AssignSystemIdentity;
    Write-Host "Successfully completed AssignSystemIdentity."
}
catch{
    Write-Host "Unexpected error occurred when trying to set AssignSystemIdentity."
}

