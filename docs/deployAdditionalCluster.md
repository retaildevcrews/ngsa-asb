# Deploy Additional clusters
## Create new spoke network

```bash
# Set Org App ID for additional spoke (this must be unique per spoke)
# export ASB_ORG_APP_ID_NAME=[starts with a-z, [a-z,0-9], min length 5, max length 11]
export ASB_ORG_APP_ID_NAME="BU0001G0002"

# Set Spoke IP address prefix
export ASB_SPOKE_IP_PREFIX="10.241"

# Create your spoke deployment file 
cp networking/spoke-BU0001A0008.json networking/spoke-$ASB_ORG_APP_ID_NAME.json

# Set spoke location
export ASB_SPOKE_LOCATION=westus2

# Ensure the following variables are set. Source the env file for reference.

echo $ASB_RG_SPOKE
echo $ASB_HUB_LOCATION
echo $ASB_VNET_HUB_ID
echo $ASB_DEPLOYMENT_NAME

# create spoke network
az deployment group create \
  -n spoke-$ASB_ORG_APP_ID_NAME \
  -g $ASB_RG_SPOKE \
  -f networking/spoke-default.json \
  -p spokeLocation=${ASB_SPOKE_LOCATION} \
     hubLocation=${ASB_HUB_LOCATION} \
     orgAppId=${ASB_ORG_APP_ID_NAME} \
     hubVnetResourceId=${ASB_VNET_HUB_ID} \
     deploymentName=${ASB_DEPLOYMENT_NAME} \
     spokeIpPrefix=${ASB_SPOKE_IP_PREFIX} -c --query name

export ASB_NODEPOOLS_SUBNET_ID=$(az deployment group show -g $ASB_RG_SPOKE -n spoke-$ASB_ORG_APP_ID_NAME --query properties.outputs.nodepoolSubnetResourceIds.value -o tsv)

# Add address range of spoke to existing hub ipGroup
az network ip-group update --name ipg-$ASB_HUB_LOCATION-AksNodepools --resource-group $ASB_RG_HUB --add ipAddresses "$ASB_SPOKE_IP_PREFIX.0.0/22"
export ASB_SPOKE_VNET_ID=$(az deployment group show -g $ASB_RG_SPOKE -n spoke-$ASB_ORG_APP_ID_NAME --query properties.outputs.clusterVnetResourceId.value -o tsv)

## TODO UPDATE HUB FIREWALL RULES
```


## Deploy Cluster

```bash
# Validate that you are using desired spoke network and orgId. Refer to network setup instructions to get correct values.
echo $ASB_SPOKE_VNET_ID
echo $ASB_ORG_APP_ID_NAME

# Set Log Analytics name
export ASB_LA_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_HUB_LOCATION} --query properties.outputs.logAnalyticsName.value -o tsv)

### Set cluster locations by choosing the closest pair - not all regions support ASB. Make sure there has not been a cluster to this region before.
# Note: cluster location must be the same as spoke location
export ASB_CLUSTER_LOCATION=${ASB_SPOKE_LOCATION}
export ASB_CLUSTER_GEO_LOCATION=westcentralus


#Set top level domain
export ASB_DOMAIN=${ASB_DNS_NAME}-${ASB_SPOKE_LOCATION}.${ASB_DNS_ZONE}

# Add DNS A Record
az network private-dns record-set a add-record -g ${ASB_RG_CORE} -z ${ASB_DNS_ZONE} -n ${ASB_DNS_NAME}-${ASB_SPOKE_LOCATION} -a ${ASB_SPOKE_IP_PREFIX}.4.4

# Add Virtual Network Link to Private DNS zones
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z ${ASB_DNS_ZONE}
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z privatelink.azurecr.io
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z privatelink.vaultcore.azure.net
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z privatelink.documents.azure.com

### this section takes 15-20 minutes

# Create AKS
az deployment group create -g $ASB_RG_CORE \
  -f cluster/cluster-stamp-additional.json \
  -n cluster-${ASB_DEPLOYMENT_NAME}-$ASB_CLUSTER_LOCATION \
  -p location=${ASB_CLUSTER_LOCATION} \
     asbDomain=${ASB_DOMAIN} \
     orgAppId=${ASB_ORG_APP_ID_NAME} \
     deploymentName=${ASB_DEPLOYMENT_NAME} \
     geoRedundancyLocation=${ASB_CLUSTER_GEO_LOCATION} \
     nodepoolsRGName=${ASB_RG_NAME} \
     targetVnetResourceId=${ASB_SPOKE_VNET_ID} \
     clusterAdminAadGroupObjectId=${ASB_CLUSTER_ADMIN_ID} \
     k8sControlPlaneAuthorizationTenantId=${ASB_TENANT_ID} \
     laWorkspaceName=${ASB_LA_NAME} \
     coreResourceGroup=${ASB_RG_CORE} \
     kubernetesVersion=${ASB_K8S_VERSION} \
     --query name -c

# Grant PullFromACR permission
export ASB_ACR_RESOURCE_ID=$(az acr show -n $ASB_ACR_NAME -g $ASB_RG_CORE --query id -o tsv)
export ASB_CLUSTER_AGENTPOOL_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-$ASB_CLUSTER_LOCATION --query properties.outputs.aksClusterName.value -o tsv)-agentpool
export ASB_CLUSTER_AGENTPOOL_RESOURCE_ID=$(az identity show -n $ASB_CLUSTER_AGENTPOOL_NAME -g $ASB_RG_CORE-nodepools-$ASB_CLUSTER_LOCATION --query principalId -o tsv)
az role assignment create --role "AcrPull" --assignee ${ASB_CLUSTER_AGENTPOOL_RESOURCE_ID} --scope ${ASB_ACR_RESOURCE_ID}

# Set public ip address resource name
export ASB_PIP_NAME='pip-'$ASB_DEPLOYMENT_NAME'-'$ASB_ORG_APP_ID_NAME'-00'

# Get cluster name
export ASB_AKS_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.aksClusterName.value -o tsv)

# Get the public IP of our App gateway
export ASB_AKS_PIP=$(az network public-ip show -g $ASB_RG_SPOKE --name $ASB_PIP_NAME --query ipAddress -o tsv)

# Get the AKS Ingress Controller Managed Identity details.
export ASB_ISTIO_RESOURCE_ID=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.aksIngressControllerPodManagedIdentityResourceId.value -o tsv)
export ASB_ISTIO_CLIENT_ID=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.aksIngressControllerPodManagedIdentityClientId.value -o tsv)
export ASB_POD_MI_ID=$(az identity show -n podmi-ingress-controller -g $ASB_RG_CORE --query principalId -o tsv)

./saveenv.sh -y
```
## Create setup files

```bash
export ASB_GIT_PATH=deploy/$ASB_DEPLOYMENT_NAME-$ASB_CLUSTER_LOCATION 

mkdir -p $ASB_GIT_PATH/istio

# istio pod identity config
cat templates/istio-pod-identity.yaml | envsubst > $ASB_GIT_PATH/istio/istio-pod-identity-config.yaml

# istio gateway config
cat templates/istio-gateway.yaml | envsubst > $ASB_GIT_PATH/istio/istio-gateway.yaml

# GitOps (flux)
mkdir -p $ASB_GIT_PATH/flux
cat templates/flux.yaml | envsubst  > $ASB_GIT_PATH/flux/flux.yaml
```

## Create DNS A record

```bash
# We are using 'dns-rg' for triplets

# resource group of DNS Zone for deployment
export ASB_DNS_ZONE_RG=dns-rg 

# create the dns record
az network dns record-set a add-record -g $ASB_DNS_ZONE_RG -z $ASB_DNS_ZONE -n $ASB_DNS_NAME-$ASB_CLUSTER_LOCATION -a $ASB_AKS_PIP --query fqdn
```
## Deploying NGSA Applications

### 🛑 Prerequisite - [Setup Cosmos DB in secure baseline](./docs/cosmos.md)
# create vnet link between private zone and spoke vnet
az network private-dns link vnet create \
  --resource-group $ASB_RG_CORE \
  --zone-name $ASB_COSMOS_ZONE \
  --name to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00 \
  --virtual-network $ASB_SPOKE_VNET_ID \
  --registration-enabled false

There are two different options to choose from for deploying NGSA:
- [Deploy using yaml with FluxCD](deployNgsaYaml.md)
- [Deploy using AutoGitops with FluxCD](./docs/deployNgsaAgo.md)
