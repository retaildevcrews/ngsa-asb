#!/bin/bash

function getSpokeVariables(){
  start_time=$(date +%s.%3N)

  echo "Getting Spoke Variables..."

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
  export ASB_SPOKE_LOCATION=$ASB_SPOKE_LOCATION

  # Make sure the DNS record does not exist
  dns_list_count=$(az network dns record-set a list -g $ASB_DNS_ZONE_RG -z $ASB_DNS_ZONE -o tsv --query [].name | grep "$ASB_SPOKE_LOCATION-$ASB_ENV" | wc -l)

  if [ $dns_list_count != 0 ]; then >&2 echo "DNS Records Already Set With $ASB_SPOKE_LOCATION Spoke Location and $ASB_ENV Environment
  Restart Script With Different Values"; exit 1; fi

  export ASB_GIT_PATH=deploy/$ASB_ENV-$ASB_DEPLOYMENT_NAME-$ASB_SPOKE_LOCATION
  export ASB_RG_SPOKE=rg-${ASB_RG_NAME}-spoke
  createResourceGroup $ASB_RG_SPOKE $ASB_SPOKE_LOCATION
  # Set default domain suffix
  # app endpoints will use subdomain from this domain suffix
  export ASB_DOMAIN_SUFFIX=${ASB_SPOKE_LOCATION}-${ASB_ENV}.${ASB_DNS_ZONE}

  end_time=$(date +%s.%3N)
  elapsed=$(echo "scale=3; $end_time - $start_time" | bc)
  echo "Completed Getting Spoke Variables. ($elapsed)"

  export ASB_SPOKE_STEP=deployDefaultSpoke
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SPOKE_STEP
}

function deployDefaultSpoke()
{
  start_time=$(date +%s.%3N)

  echo "Deploying Default Spoke..."

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

  if [ -z $ASB_NODEPOOLS_SUBNET_ID ]; then echo "Step deployDefaultSpoke failed" 1>&2; exit 1; fi

  end_time=$(date +%s.%3N)
  elapsed=$(echo "scale=3; $end_time - $start_time" | bc)
  echo "Completed Deploying Default Spoke. ($elapsed)"

  export ASB_SPOKE_STEP=deployHubRegionA
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SPOKE_STEP
}

function deployHubRegionA()
{
  start_time=$(date +%s.%3N)

  echo "Deploying Hub Region A..."

  # Create Region A hub network
  az deployment group create \
    -g $ASB_RG_HUB \
    -f networking/hub-regionA.json \
    -p location=${ASB_HUB_LOCATION} nodepoolSubnetResourceIds="['${ASB_NODEPOOLS_SUBNET_ID}']" \
    -c --query name

  # Get spoke vnet id
  export ASB_SPOKE_VNET_ID=$(az deployment group show -g $ASB_RG_SPOKE -n spoke-$ASB_ORG_APP_ID_NAME --query properties.outputs.clusterVnetResourceId.value -o tsv)

  if [ -z $ASB_SPOKE_VNET_ID ]; then echo "Step deployHubRegionA failed" 1>&2; exit 1; fi

  end_time=$(date +%s.%3N)
  elapsed=$(echo "scale=3; $end_time - $start_time" | bc)
  echo "Completed Deploying Hub Region A. ($elapsed)"

  export ASB_SPOKE_STEP=deployAks
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SPOKE_STEP
}

function deployAks()
{
  start_time=$(date +%s.%3N)
  echo "Deploying AKS..."

  # Validate that you are using the correct vnet for cluster deployment
  echo $ASB_SPOKE_VNET_ID
  echo $ASB_ORG_APP_ID_NAME

  # Set cluster location by choosing the closest pair - not all regions support ASB.
  # Note: Cluster location must be the same as spoke location
  export ASB_CLUSTER_LOCATION=${ASB_SPOKE_LOCATION}

  echo "Geo Location Pairings Can Be Found Here: https://learn.microsoft.com/en-us/azure/availability-zones/cross-region-replication-azure#azure-cross-region-replication-pairings-for-all-geographies"
  # Cluster Geo Location Prompt
  PS3="Select Cluster Geo Location: "
  select ASB_CLUSTER_GEO_LOCATION in "${location_selections[@]}"
  do
    if [[ "$ASB_CLUSTER_GEO_LOCATION" ]]; then
      echo "Location Selected: $ASB_CLUSTER_GEO_LOCATION"
      break
    else
      echo "Number Not In Range, Try Again"
    fi
  done
  export ASB_CLUSTER_GEO_LOCATION=$ASB_CLUSTER_GEO_LOCATION

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


  # Get cluster name
  export ASB_AKS_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.aksClusterName.value -o tsv)

  if [ -z $ASB_AKS_NAME ]; then echo "Step deployAks failed" 1>&2; exit 1; fi

  end_time=$(date +%s.%3N)
  elapsed=$(echo "scale=3; $end_time - $start_time" | bc)

  echo "Completed Deploying AKS. ($elapsed)"

  export ASB_SPOKE_STEP=getClusterContext

  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SPOKE_STEP
}

function getClusterContext()
{
  echo "Getting Cluster Context..."

  # Get AKS credentials
  az aks get-credentials -g $ASB_RG_CORE -n $ASB_AKS_NAME

  kubelogin convert-kubeconfig -l azurecli

  # Check the nodes
  # Requires Azure login
  kubectl get nodes

  # Check the pods
  kubectl get pods -A

  echo "Completed Getting Cluster Context."

  export ASB_SPOKE_STEP=setAksVariables
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SPOKE_STEP
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

  export ASB_SPOKE_STEP=createDnsRecord
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SPOKE_STEP
}

function createDnsRecord()
{
  echo "Creating Public DNS A Record..."

  # Create public DNS record for ngsa-memory
  az network dns record-set a add-record -g $ASB_DNS_ZONE_RG -z $ASB_DNS_ZONE -n "ngsa-memory-${ASB_SPOKE_LOCATION}-${ASB_ENV}" -a $ASB_AKS_PIP --query fqdn

  echo "Completed Creating Public DNS A Record."

  export ASB_SPOKE_STEP=createDeploymentFiles
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SPOKE_STEP
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

  export ASB_SPOKE_STEP=pushToGit
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SPOKE_STEP
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

  export ASB_SPOKE_STEP=deployFluxPrerequisites
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SPOKE_STEP
}

function deployFluxPrerequisites()
{
  echo "Deploying Flux Prerequisites..."

  # Import Flux Dependencies To ACR
  az acr import --source docker.io/fluent/fluent-bit:1.9.5 -n $ASB_ACR_NAME
  az acr import --source docker.io/prom/prometheus:v2.30.0 -n $ASB_ACR_NAME
  az acr import --source docker.io/grafana/grafana:8.5.5 -n $ASB_ACR_NAME
  az acr import --source quay.io/thanos/thanos:v0.23.0 -n $ASB_ACR_NAME

  echo "Creating secrets to authenticate with log analytics..."
  # Create secrets to authenticate with log analytics
  kubectl create secret generic fluentbit-secrets --from-literal=WorkspaceId=$(az monitor log-analytics workspace show -g $ASB_RG_CORE -n $ASB_LA_NAME --query customerId -o tsv)   --from-literal=SharedKey=$(az monitor log-analytics workspace get-shared-keys -g $ASB_RG_CORE -n $ASB_LA_NAME --query primarySharedKey -o tsv) -n fluentbit

  export ASB_SPOKE_STEP=deployFlux
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SPOKE_STEP
}

function deployFlux()
{
  echo "Deploying Flux.."

  # ASB uses `Flux v2` for `GitOps`

  # Before deploying flux we need to import the flux images to ACR.

  # Make sure your IP is added to ACR for image push access.
  # Goto the ACR in Azure Portal -> Networking -> Add your client IP -> Save

  # Import all Flux images to private ACR
  grep 'image:' flux-init/base/gotk-components.yaml | awk '{print $2}' | xargs -I_ az acr import --source "_" -n $ASB_ACR_NAME

  # Setup flux base system (replace bootstrap folder with dev-bootstrap for dev env)
  kubectl create -k ${ASB_FLUX_INIT_DIR}
  # Note: If flux v2 exists in cluster, use "kubectl apply -k"
  # Note: if "kubectl create/apply -k" fails once (sometimes CRD takes some time to be injected into the API), then simply reapply

  # Setup zone specific deployment
  kubectl apply -f $ASB_DEPLOYMENT_PATH/flux-kustomization/${ASB_CLUSTER_LOCATION}-kustomization.yaml

  # 🛑 Check the pods until everything is running
  kubectl get pods -n flux-system

  # Check flux syncing git repo logs
  kubectl logs -n flux-system -l app=source-controller

  # Check flux syncing kustomization logs
  kubectl logs -n flux-system -l app=kustomize-controller

  # List all flux kustmization in the cluster
  # It also shows the state of each kustomization
  flux get kustomizations -A

  echo "Completed Deploying Flux."

  export ASB_SPOKE_STEP=showNextSteps
  # Save environment variables
  ./saveenv.sh -y

  # Invoke Next Step In Setup
  $ASB_SPOKE_STEP
}

function showNextSteps(){
  echo "All Complete! Continue with https://github.com/retaildevcrews/ngsa-asb#deploying-ngsa-applications. (Deploying NGSA Applications)
  If you wish to add another cluster/spoke, follow this readme: docs/deployAdditionalCluster.md"
}

if test -f .current-deployment; then
  if test -f $(cat .current-deployment); then
    source $(cat .current-deployment)
  else
    export ASB_SPOKE_STEP=getSpokeVariables
  fi
else
  export ASB_SPOKE_STEP=getSpokeVariables
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

if [[ $1 == $ASB_RG_HUB ]]; then
  echo "Starting script at step: $ASB_SPOKE_STEP"
  #start at step
  $ASB_SPOKE_STEP $1
else
  >&2 echo "Your saved environment variables do not support attaching to selected hub"; exit 1;
fi
