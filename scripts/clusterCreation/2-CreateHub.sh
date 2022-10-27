#!/bin/bash

function collectInputParameters()
{
  echo $1
  if [ -z $1 ]; then
    echo "Please provide the Cluster Admin ID when calling this script" 1>&2
    echo "This command can be retrieved by running ./clusterCreation/getClusterAdminIDforDeployment.sh from your local machine (not CodeSpaces)" 1>&2
    exit 1
  else 
    export ASB_CLUSTER_ADMIN_ID=$1

    export ASB_SCRIPT_STEP=setDeploymentName

      # Save environment variables
    ./saveenv.sh -y

    # Invoke Next Step In Setup
    $ASB_SCRIPT_STEP
  fi
}

function setDeploymentName()
{
  function isValidDeploymentName() {
    [[ "$1" =~ ^[a-z]([a-z]|[[:digit:]]){2,7}$ ]]
  }
  requirements="* Deployment Name Requirements:
* must be lowercase
* must start with a-z
* must only be a-z or 0-9
* max length is 8
* min length is 3"

  while ! isValidDeploymentName "$ASB_DEPLOYMENT_NAME";do
      read -p "$requirements
Enter Deployment Name: " ASB_DEPLOYMENT_NAME
  done

  export ASB_DEPLOYMENT_NAME=$ASB_DEPLOYMENT_NAME
  export ASB_ENV=dev

  echo "Type Environment Name (Press Enter to accept default of $ASB_ENV):"
  read ans
  if [[ $ans ]]; then
    export ASB_ENV=$ans
  fi

  export ASB_RG_NAME=${ASB_DEPLOYMENT_NAME}-${ASB_ENV}

  #setDeploymentRegion
}

function setDeploymentRegion()
{
  azure_locations=( "australiaeast" "centralus" "eastus" "eastus2" "japaneast" "northeurope" "southcentralus" "southeastasia" "uksouth" "westeurope" "westus2" "WestUS3" )
  location_selections=( "${azure_locations[@]##*/}" )

  # Hub Location Prompt
  PS3="Select Hub (Not Cluster) Location: "
  select ASB_HUB_LOCATION in "${location_selections[@]}"
  do
    if [[ "$ASB_HUB_LOCATION" ]]; then
      echo "Location Selected: $ASB_HUB_LOCATION"
      break
    else
      echo "Number Not In Range, Try Again"
    fi
  done

  export ASB_HUB_LOCATION=$ASB_HUB_LOCATION

  export ASB_ORG_APP_ID_NAME="BU0001G0001"

  export ASB_SCRIPT_STEP=checkoutBranch
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function checkoutBranch()
{
  # Create a branch for your cluster
  # Do not change the branch name from $ASB_RG_NAME
  git checkout -b $ASB_RG_NAME
  git push -u origin $ASB_RG_NAME

  export ASB_SCRIPT_STEP=getAadValues
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function getAadValues()
{
  echo "Getting AAD Values..."

  # Export Subscription ID
  export ASB_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

  # Export AAD env vars
  export ASB_TENANT_ID=$(az account show --query tenantId -o tsv)

  echo "Completed Getting AAD Values."

  export ASB_SCRIPT_STEP=setVariablesForDeployment
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function setVariablesForDeployment()
{
  echo "Getting AAD Values..."

  # Set GitOps repo
  export ASB_GIT_REPO=$(git remote get-url origin)
  export ASB_GIT_BRANCH=$ASB_RG_NAME

  # Resource group names
  export ASB_RG_CORE=rg-${ASB_RG_NAME}
  export ASB_RG_HUB=rg-${ASB_RG_NAME}-hub

  echo "Completed Getting AAD Values."

  export ASB_SCRIPT_STEP=createResourceGroups
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function createResourceGroups()
{
  function createResourceGroup(){
    echo "Creating Resource Group $1..."
    if [ $(az group exists --name $1) = true ]; then 
      echo "resource group $1 already exists."
    else
      az group create -n $1 -l $2 
      echo "Creating resource group $1."
    fi
  }

  echo "Creating Resource Groups..."

  createResourceGroup $ASB_RG_CORE $ASB_HUB_LOCATION
  createResourceGroup $ASB_RG_HUB $ASB_HUB_LOCATION
  
  echo "Completed Creating Resource Groups."

  export ASB_SCRIPT_STEP=deployDefaultHub
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function deployDefaultHub()
{
  start_time=$(date +%s.%3N)

  echo "Deploying Default Hub..."

  # Create hub network
  az deployment group create \
    -g $ASB_RG_HUB \
    -f networking/hub-default.json \
    -p location=${ASB_HUB_LOCATION} \
    -c --query name

  export ASB_HUB_VNET_ID=$(az deployment group show -g $ASB_RG_HUB -n hub-default --query properties.outputs.hubVnetId.value -o tsv)

  if [ -z $ASB_HUB_VNET_ID ]; then echo "Step deployDefaultHub failed" 1>&2; exit 1; fi

  end_time=$(date +%s.%3N)
  elapsed=$(echo "scale=3; $end_time - $start_time" | bc)
  echo "Completed Deploying Default Hub. ($elapsed)"

  export ASB_SCRIPT_STEP=showNextSteps
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}
function showNextSteps(){
  echo "Completed Deploying Hub"
  echo "Continue Setup By Creating A Spoke And Cluster: ./scripts/clusterCreation/2-AttachSpokeAndClusterToHub.sh $ASB_RG_HUB"
}

if test -f .current-deployment; then
  if test -f $(cat .current-deployment); then
    source $(cat .current-deployment)
  else
    export ASB_SCRIPT_STEP=collectInputParameters
  fi
else
  export ASB_SCRIPT_STEP=collectInputParameters
fi

# Validate script being run from CodeSpaces
# These env vars are already set in Codespaces enviroment for "cse.ms"
# Check certificates
if [ -z $APP_GW_CERT_CSMS ]; then >&2 echo "Please run script using CodeSpaces"; exit 1; fi
if [ -z $INGRESS_CERT_CSMS ]; then >&2 echo "Please run script using CodeSpaces"; exit 1; fi
if [ -z $INGRESS_KEY_CSMS ]; then >&2 echo "Please run script using CodeSpaces"; exit 1; fi

#check if logged into azure
if az account show -o none; then
  echo "Your are logged into Azure subscription $(az account show --query name)"
else
  echo "Please run 'az login --use-device-code' before continuing" 1>&2
  exit 1
fi

#start at step
$ASB_SCRIPT_STEP $1
