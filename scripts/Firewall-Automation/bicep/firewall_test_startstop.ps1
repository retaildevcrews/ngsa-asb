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
    [String]$managedIdentityClientId,
    [Parameter(Mandatory)]
    [String]$operation
)
try{
    # Ensures you do not inherit an AzContext in your runbook
    Write-Output "Disabling AzContext Autosave"
    Disable-AzContextAutosave -Scope Process | Out-Null
    
    Write-Output "Connect-AzAccount -Identity -AccountId" $managedIdentityClientId
    $AzureContext = (Connect-AzAccount -Identity -AccountId $managedIdentityClientId).context
    # set and store context
    Write-Output "Setting context"
    $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
    Write-Output "Finished setting the Azure context for subscription" 
    
    Write-Output "FIREWALL TESTING: Executing operation: $operation"
    switch($operation.ToLower())
    {
        "start"{
            Write-Output "FIREWALL TESTING Start ..."
            
        }
        "stop"{
            Write-Output "FIREWALL TESTING Stop ..."
        }
        Default {
            Write-Output "Invalid Operation, supported operations are start and stop"
        }
    }
    
    Write-Output "Completed operation: $operation."
    return $LASTEXITCODE
    }
    catch{
        $message = $_
        Write-Output "Script exiting with the following error:  $message"
        throw $_
    }
