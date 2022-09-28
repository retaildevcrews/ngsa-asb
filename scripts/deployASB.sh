#!/bin/bash

function checkPermissions()
{
  # check admin
  setDeploymentName
}

function setDeploymentName()
{
  function promptDeploymentName() {
    read -p "Enter Deployment Name: " ASB_DEPLOYMENT_NAME
    if [[ "$ASB_DEPLOYMENT_NAME" =~ "^[a-z][^_\W]{2,7}$" ]]; then
      exit 0
    else
      exit 1
    fi
  }
  until promptDeploymentName; do : ; done

  setDeploymentRegion
}



function setDeploymentRegion()
{
  azure_locations=( $(az account list-locations --query [].id -o tsv) )
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

  # We are using 'dns-rg' for triplets
  export ASB_DNS_ZONE_RG=dns-rg
  export ASB_DNS_ZONE=cse.ms

  # Spoke Location Prompt
  PS3="Select Spoke (Not Cluster) Location: "
  select ASB_SPOKE_LOCATION in "${location_selections[@]}"
  do
    if [[ "$ASB_SPOKE_LOCATION" ]]; then
      echo "Location Selected: $ASB_SPOKE_LOCATION"
      break
    else
      echo "Number Not In Range, Try Again"
    fi
  done

  # Make sure the DNS record does not exist
  az network dns record-set a list -g $ASB_DNS_ZONE_RG -z $ASB_DNS_ZONE -o table | grep "$ASB_SPOKE_LOCATION-$ASB_ENV"

  # If any records exist, choose a different deployment region and try again

  export ASB_SCRIPT_STEP=checkoutBranch
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function checkoutBranch()
{
  export ASB_SCRIPT_STEP=validateIngressVariables
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function validateIngressVariables()
{
  echo "Validating Ingress Variables Set By CodeSpaces..."

  # These env vars are already set in Codespaces enviroment for "cse.ms"
  # Check certificates
  if [ -z $APP_GW_CERT_CSMS ]; then >&2 echo "App Gateway cert not set correctly"; exit 1; fi
  if [ -z $INGRESS_CERT_CSMS ]; then >&2 echo "Ingress cert not set correctly"; exit 1; fi
  if [ -z $INGRESS_KEY_CSMS ]; then >&2 echo "Ingress key not set correctly"; exit 1; fi

  echo "Completed Validating Ingress Variables Set By CodeSpaces."
  
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

  # Get AAD cluster admin group
  export ASB_CLUSTER_ADMIN_ID=$(az ad group show -g $ASB_CLUSTER_ADMIN_GROUP --query id -o tsv)

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
  export ASB_GIT_PATH=deploy/$ASB_ENV-$ASB_DEPLOYMENT_NAME-$ASB_SPOKE_LOCATION

  # Set default domain suffix
  # app endpoints will use subdomain from this domain suffix
  export ASB_DOMAIN_SUFFIX=${ASB_SPOKE_LOCATION}-${ASB_ENV}.${ASB_DNS_ZONE}

  # Resource group names
  export ASB_RG_CORE=rg-${ASB_RG_NAME}
  export ASB_RG_HUB=rg-${ASB_RG_NAME}-hub
  export ASB_RG_SPOKE=rg-${ASB_RG_NAME}-spoke

  echo "Completed Getting AAD Values."

  export ASB_SCRIPT_STEP=createResourceGroups
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function createResourceGroups()
{
  echo "Creating Resource Groups..."

  az group create -n $ASB_RG_CORE -l $ASB_HUB_LOCATION
  az group create -n $ASB_RG_HUB -l $ASB_HUB_LOCATION
  az group create -n $ASB_RG_SPOKE -l $ASB_SPOKE_LOCATION

  echo "Completed Creating Resource Groups."

  export ASB_SCRIPT_STEP=deployHubAndSpoke
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function deployHubAndSpoke()
{
  echo "Deploying Hub and Spoke..."

  # Create hub network
  az deployment group create \
    -g $ASB_RG_HUB \
    -f networking/hub-default.json \
    -p location=${ASB_HUB_LOCATION} \
    -c --query name

  export ASB_HUB_VNET_ID=$(az deployment group show -g $ASB_RG_HUB -n hub-default --query properties.outputs.hubVnetId.value -o tsv)

  # Set spoke ip address prefix
  export ASB_SPOKE_IP_PREFIX="10.240"

  # Create spoke network
  az deployment group create \
    -n spoke-$ASB_ORG_APP_ID_NAME \
    -g $ASB_RG_SPOKE \
    -f networking/spoke-default.json \
    -p deploymentName=${ASB_DEPLOYMENT_NAME} \
      hubLocation=${ASB_HUB_LOCATION} \
      hubVnetResourceId=${ASB_HUB_VNET_ID} \
      orgAppId=${ASB_ORG_APP_ID_NAME} \
      spokeIpPrefix=${ASB_SPOKE_IP_PREFIX} \
      spokeLocation=${ASB_SPOKE_LOCATION} \
    -c --query name

  # Get nodepools subnet id from spoke
  export ASB_NODEPOOLS_SUBNET_ID=$(az deployment group show -g $ASB_RG_SPOKE -n spoke-$ASB_ORG_APP_ID_NAME --query properties.outputs.nodepoolSubnetResourceIds.value -o tsv)

  # Create Region A hub network
  az deployment group create \
    -g $ASB_RG_HUB \
    -f networking/hub-regionA.json \
    -p location=${ASB_HUB_LOCATION} nodepoolSubnetResourceIds="['${ASB_NODEPOOLS_SUBNET_ID}']" \
    -c --query name

  # Get spoke vnet id
  export ASB_SPOKE_VNET_ID=$(az deployment group show -g $ASB_RG_SPOKE -n spoke-$ASB_ORG_APP_ID_NAME --query properties.outputs.clusterVnetResourceId.value -o tsv)

  echo "Completed Deploying Hub and Spoke."

  export ASB_SCRIPT_STEP=deployAks
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function deployAks()
{
  echo "Deploying AKS..."

  # Validate that you are using the correct vnet for cluster deployment
  echo $ASB_SPOKE_VNET_ID
  echo $ASB_ORG_APP_ID_NAME

  # Set cluster location by choosing the closest pair - not all regions support ASB.
  # Note: Cluster location must be the same as spoke location
  export ASB_CLUSTER_LOCATION=${ASB_SPOKE_LOCATION}
  export ASB_CLUSTER_GEO_LOCATION=westus

  # This section takes 15-20 minutes

  # Set Kubernetes Version
  export ASB_K8S_VERSION=1.23.8

  # Create AKS
  az deployment group create -g $ASB_RG_CORE \
    -f cluster/cluster-stamp.json \
    -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} \
    -p appGatewayListenerCertificate=${APP_GW_CERT_CSMS} \
      asbDomainSuffix=${ASB_DOMAIN_SUFFIX} \
      asbDnsName=${ASB_SPOKE_LOCATION}-${ASB_ENV} \
      asbDnsZone=${ASB_DNS_ZONE} \
      aksIngressControllerCertificate="$(echo $INGRESS_CERT_CSMS | base64 -d)" \
      aksIngressControllerKey="$(echo $INGRESS_KEY_CSMS | base64 -d)" \
      clusterAdminAadGroupObjectId=${ASB_CLUSTER_ADMIN_ID} \
      deploymentName=${ASB_DEPLOYMENT_NAME} \
      geoRedundancyLocation=${ASB_CLUSTER_GEO_LOCATION} \
      hubVnetResourceId=${ASB_HUB_VNET_ID} \
      k8sControlPlaneAuthorizationTenantId=${ASB_TENANT_ID} \
      kubernetesVersion=${ASB_K8S_VERSION} \
      location=${ASB_CLUSTER_LOCATION} \
      nodepoolsRGName=${ASB_RG_NAME} \
      orgAppId=${ASB_ORG_APP_ID_NAME} \
      targetVnetResourceId=${ASB_SPOKE_VNET_ID} \
      -c --query name

  echo "Completed Deploying AKS."

  export ASB_SCRIPT_STEP=validateAks
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function validateAks()
{
  echo "Deploying AKS..."

  # Get cluster name
  export ASB_AKS_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.aksClusterName.value -o tsv)

  # Get AKS credentials
  az aks get-credentials -g $ASB_RG_CORE -n $ASB_AKS_NAME

  # Rename context for simplicity
  kubectl config rename-context $ASB_AKS_NAME $ASB_DEPLOYMENT_NAME-${ASB_CLUSTER_LOCATION}

  # Check the nodes
  # Requires Azure login
  kubectl get nodes

  # Check the pods
  kubectl get pods -A

  echo "Completed Deploying AKS."

  export ASB_SCRIPT_STEP=setAksVariables
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function setAksVariables()
{
  echo "Setting AKS Variables..."

  # Set public ip address resource name
  export ASB_PIP_NAME='pip-'$ASB_DEPLOYMENT_NAME'-'$ASB_ORG_APP_ID_NAME'-00'

  # Get the public IP of our App gateway
  export ASB_AKS_PIP=$(az network public-ip show -g $ASB_RG_SPOKE --name $ASB_PIP_NAME --query ipAddress -o tsv)

  # Get the AKS Ingress Controller Managed Identity details.
  export ASB_ISTIO_RESOURCE_ID=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.aksIngressControllerPodManagedIdentityResourceId.value -o tsv)
  export ASB_ISTIO_CLIENT_ID=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.aksIngressControllerPodManagedIdentityClientId.value -o tsv)
  export ASB_POD_MI_ID=$(az identity show -n podmi-ingress-controller -g $ASB_RG_CORE --query principalId -o tsv)

  # Get the name of Azure Container Registry
  export ASB_ACR_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION}  --query properties.outputs.containerRegistryName.value -o tsv)

  # Get Log Analytics Name
  export ASB_LA_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_HUB_LOCATION} --query properties.outputs.logAnalyticsName.value -o tsv)

  # Get Log Analytics Workspace ID
  export ASB_LA_WORKSPACE_ID=$(az monitor log-analytics workspace show -g $ASB_RG_CORE -n $ASB_LA_NAME --query customerId -o tsv)

  # Get the name of KeyVault
  export ASB_KV_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.keyVaultName.value -o tsv)

  # Config certificate names
  export ASB_INGRESS_CERT_NAME=appgw-ingress-internal-aks-ingress-tls
  export ASB_INGRESS_KEY_NAME=appgw-ingress-internal-aks-ingress-key

  echo "Completed Setting AKS Variables."

  export ASB_SCRIPT_STEP=createDnsRecord
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function createDnsRecord()
{
  echo "Creating Public DNS A Record..."

  # Create public DNS record for ngsa-memory
  az network dns record-set a add-record -g $ASB_DNS_ZONE_RG -z $ASB_DNS_ZONE -n "ngsa-memory-${ASB_SPOKE_LOCATION}-${ASB_ENV}" -a $ASB_AKS_PIP --query fqdn

  echo "Completed Creating Public DNS A Record."

  export ASB_SCRIPT_STEP=createDeploymentFiles
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function createDeploymentFiles()
{
  echo "Creating Deployment Files..."

  mkdir -p $ASB_GIT_PATH/istio

  # istio pod identity config
  cat templates/istio/istio-pod-identity-config.yaml | envsubst > $ASB_GIT_PATH/istio/istio-pod-identity-config.yaml

  # istio gateway config
  cat templates/istio/istio-gateway.yaml | envsubst > $ASB_GIT_PATH/istio/istio-gateway.yaml

  # istio ingress config
  cat templates/istio/istio-ingress.yaml | envsubst > $ASB_GIT_PATH/istio/istio-ingress.yaml

  # GitOps (flux v2)
  rm -f deploy/bootstrap/flux-system/gotk-repo.yaml
  cat templates/flux-system/gotk-repo.yaml | envsubst  >| deploy/bootstrap/flux-system/gotk-repo.yaml
  # Note: if separate bootstrap folder (dev-bootstrap) for dev env exists, then replace `bootstrap` with `dev-bootstrap`
  # rm -f deploy/dev-bootstrap/flux-system/gotk-repo.yaml
  # cat templates/flux-system/gotk-repo.yaml | envsubst  >| deploy/dev-bootstrap/flux-system/gotk-repo.yaml

  echo "Completed Creating Deployment Files."

  export ASB_SCRIPT_STEP=pushToGit
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function pushToGit()
{
  echo "Pushing To Github.."

  # The setup process creates 4 new files
  # GitOps will not work unless these files are merged into your branch
  # Check deltas - there should be 4 new files
  git status

  # Push to your branch istio changes
  git add $ASB_GIT_PATH/istio/istio-pod-identity-config.yaml
  git add $ASB_GIT_PATH/istio/istio-gateway.yaml
  git add $ASB_GIT_PATH/istio/istio-ingress.yaml

  git commit -m "added cluster config"

  # Add and push Flux branch and repo info
  git add deploy/bootstrap/flux-system/
  # Note: if separate bootstrap folder (dev-bootstrap) for dev env exists, then replace `bootstrap` with `dev-bootstrap`
  # git add deploy/dev-bootstrap/flux-system/
  git commit -m "added flux bootstrap config"

  git push

  echo "Completed Pushing To Github."

  export ASB_SCRIPT_STEP=deployFlux
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function deployFlux()
{
  echo "Deploying Flux.."

  # ASB uses `Flux v2` for `GitOps`

  # Before deploying flux we need to import the flux images to ACR.

  # Make sure your IP is added to ACR for image push access.
  # Goto the ACR in Azure Portal -> Networking -> Add your client IP -> Save

  # Import all Flux images to private ACR
  grep 'image:' deploy/bootstrap/flux-system/gotk-components.yaml | awk -F'azurecr.io' '{print $2}' | xargs -I_ az acr import --source "ghcr.io_" -n $ASB_ACR_NAME

  # Setup flux base system (replace bootstrap folder with dev-bootstrap for dev env)
  kubectl create -k deploy/bootstrap/flux-system/
  # Note: If flux v2 exists in cluster, use "kubectl apply -k"
  # Note: if "kubectl create/apply -k" fails once (sometimes CRD takes some time to be injected into the API), then simply reapply

  # Setup zone specific deployment
  kubectl apply -f $ASB_GIT_PATH/flux-kustomization/${ASB_CLUSTER_LOCATION}-kustomization.yaml

  # 🛑 Check the pods until everything is running
  kubectl get pods -n flux-system

  # Check flux syncing git repo logs
  kubectl logs -n flux-system -l app=source-controller

  # Check flux syncing kustomization logs
  kubectl logs -n flux-system -l app=kustomize-controller

  # List all flux kustmization in the cluster
  # It also shows the state of each kustomization
  flux get kustomizations -A

  # Reconcile (sync) one individual kustomization
  flux reconcile kustomization -n ngsa ngsa # note the namespace `-n ngsa`

  # Reconcile (sync) all flux kustomization in the cluster
  flux get kustomizations -A --no-header | awk -F' ' '{printf "%s -n %s\n",$2, $1}' | xargs -L 1 -I_ sh -c "flux reconcile kustomization _"

  # Suspend one flux kustomization from reconciliation (sync)
  # flux suspend kustomization -n ngsa ngsa # note the namespace `-n ngsa`

  # Suspend the git source from updating (should suspend any updates from the git repo)
  # flux suspend source git asb-repo-flux

  echo "Completed Deploying Flux."

  export ASB_SCRIPT_STEP=showNextSteps
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SCRIPT_STEP
}

function showNextSteps(){

  echo "All Complete! Continue with readme"
}


#read variables
source .env file

#check if in codespaces

#check logged into azure

#start at step
$ASB_SCRIPT_STEP
