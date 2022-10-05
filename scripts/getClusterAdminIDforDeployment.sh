#!/bin/bash

function GetClusterAdminID(){
    echo "Getting Cluster Admin ID..."
    az login --use-device-code 

    export ASB_CLUSTER_ADMIN_GROUP=4-co

    az ad group show -g $ASB_CLUSTER_ADMIN_GROUP --query id -o tsv
}

GetClusterAdminID