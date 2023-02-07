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
    [String]$operation,
    [bool]$skiprun = $false
)
try{
    if ($skiprun){
        Write-Output "Skipping run."
        Exit(0)
    }
    # Ensures you do not inherit an AzContext in your runbook
    Write-Output "Disabling AzContext Autosave"
    Disable-AzContextAutosave -Scope Process | Out-Null
    
    Write-Output "Connect-AzAccount -Identity -AccountId" $managedIdentityClientId
    $AzureContext = (Connect-AzAccount -Identity -AccountId $managedIdentityClientId).context
    # set and store context
    Write-Output "Setting context"
    $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
    Write-Output "Finished setting the Azure context for subscription" 
    
    Write-Output "Executing operation: $operation on cluster: $clusterName and gateway: $gatewayName"
    switch($operation.ToLower())
    {
        "start"{
            Write-Output "Start-AzAksCluster -Name $clusterName -ResourceGroupName $resourceGroup"
            Start-AzAksCluster -Name $clusterName -ResourceGroupName $resourceGroup
            Write-Output "Get-AzApplicationGateway -Name $gatewayName -ResourceGroupName $resourceGroup"
            $appGateway = Get-AzApplicationGateway -Name $gatewayName -ResourceGroupName $resourceGroup
            Write-Output "Start-AzApplicationGateway -ApplicationGateway $appGateway"
            Start-AzApplicationGateway -ApplicationGateway $appGateway
        }
        "stop"{
            Write-Output "$appGateway = Get-AzApplicationGateway -Name $gatewayName -ResourceGroupName $resourceGroup"
            $appGateway = Get-AzApplicationGateway -Name $gatewayName -ResourceGroupName $resourceGroup
            Write-Output "Stop-AzApplicationGateway -ApplicationGateway $appGateway"
            Stop-AzApplicationGateway -ApplicationGateway $appGateway
            Write-Output "Stop-AzAksCluster -Name $clusterName -ResourceGroupName $resourceGroup"
            Stop-AzAksCluster -Name $clusterName -ResourceGroupName $resourceGroup
        }
        Default {
            Write-Output "Invalid Operation, supported operations are start and stop"
        }
    }
    
    Write-Output "Completed operation: $operation on cluster: $clusterName and gateway: $gatewayName"
    return $LASTEXITCODE
    }
    catch{
        $message = $_
        Write-Output "Script exiting with the following error:  $message"
        throw $_
    }
