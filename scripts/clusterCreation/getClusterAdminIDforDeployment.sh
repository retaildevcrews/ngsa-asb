#!/bin/bash

function GetClusterAdminID(){
    if az ad signed-in-user show -o none; then
        echo "You are in to Azure as user $(az account show --query user.name)"
        echo "You are logged into Azure subscription $(az account show --query name)"
    else
        echo "Sign into Azure. You may be redirected."
        az login -o none
        subscriptions=( $(az account list --query [].name -o tsv) )
        PS3="Select subscription to use: "
        select subscriptionName in "${subscriptions[@]}"
        do
            if [[ "$subscriptionName" ]]; then
            echo "Subscription Selected: $subscriptionName"
            az account set -s $subscriptionName
            break
            else
            echo "Number Not In Range, Try Again"
            fi
        done
    fi

    export ASB_CLUSTER_ADMIN_GROUP=ADC-ADM

    echo "Type Cluster Admin Group Name (Press Enter to accept default of $ASB_CLUSTER_ADMIN_GROUP):"
    read ans
    if [[ $ans ]]; then
        export ASB_CLUSTER_ADMIN_GROUP=$ans
    fi

    # Verify you are a member of the security group
    echo "Checking if you are a member of group $ASB_CLUSTER_ADMIN_GROUP..."
    if $(az ad group member check -g $ASB_CLUSTER_ADMIN_GROUP --member-id $(az ad signed-in-user show --query id -o tsv) --query value -o tsv); then
        echo You a member of group $ASB_CLUSTER_ADMIN_GROUP
    else
        >&2 echo "You are not a member of group $ASB_CLUSTER_ADMIN_GROUP"
        exit 1;
    fi
    
    echo "Getting Admin Group ID..."
    ASB_CLUSTER_ADMIN_ID=$(az ad group show -g $ASB_CLUSTER_ADMIN_GROUP --query id -o tsv)
}
function CheckSubscriptionAccess(){
    # Check if owner or contributor for subscription
    subscription_id=$(az account show --query id -o tsv)
    userId=$(az ad signed-in-user show --query id -o tsv)
    groupRoleInSubscriptions=$(az role assignment list --assignee $ASB_CLUSTER_ADMIN_ID --query '[].roleDefinitionName' -o tsv)
    desiredRoles=("Owner" "Contributor")
    for roleInSubscription in ${groupRoleInSubscriptions[@]}; do
        for desiredRole in ${desiredRoles[@]}; do
            if [[ $desiredRole == $roleInSubscription ]]; then
                export doesUserHaveDesiredRole=true
            fi
        done
    done

    if [ -z $doesUserHaveDesiredRole ]; then >&2 echo "You Need To Have Elevated Privileges To This Subscription.
    Elevated Privileges are: $(IFS=, ; echo "${desiredRoles[*]}")"; exit 1; else echo "You have elevated permission to this subscription."; fi
}

GetClusterAdminID
CheckSubscriptionAccess
echo "Checking Subsciption and Admin Group Permissions Complete"
echo "Continue to follow setup in CodeSpaces"
echo "Once in CodeSpaces enter the following command: ./scripts/clusterCreation/deployASB.sh $ASB_CLUSTER_ADMIN_ID"