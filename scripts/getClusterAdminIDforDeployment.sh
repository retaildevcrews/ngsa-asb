#!/bin/bash

function GetClusterAdminID(){
    echo "Getting Cluster Admin ID..."

    if az account show -o none; then
        echo "You are in to Azure as user $(az account show --query user.name)"
        echo "You are logged into Azure subscription $(az account show --query name)"
    else
        az login --use-device-code --output none
    fi

    export ASB_CLUSTER_ADMIN_GROUP=4-co
    
    cluster_admin_id=$(az ad group show -g $ASB_CLUSTER_ADMIN_GROUP --query id -o tsv)
    echo ""
    echo "Clusater Admin ID: $cluster_admin_id"
}

GetClusterAdminID