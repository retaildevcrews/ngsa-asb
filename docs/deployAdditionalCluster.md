# Deploy Additional clusters

## Create  Spoke Network

```bash
# Set Org App ID for additional spoke (this must be unique per spoke)
# export ASB_ORG_APP_ID_NAME=[starts with a-z, [a-z,0-9], min length 5, max length 11]
export ASB_ORG_APP_ID_NAME="BU0001G0002"

# Set Spoke IP address prefix
export ASB_SPOKE_IP_PREFIX="10.241"

# Set spoke location
export ASB_SPOKE_LOCATION=westus2

# Ensure the following variables are set. Source the env file for reference.

echo $ASB_RG_SPOKE
echo $ASB_HUB_LOCATION
echo $ASB_HUB_VNET_ID
echo $ASB_DEPLOYMENT_NAME

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

# Add address range of spoke to existing hub ipGroup
az network ip-group update --name ipg-$ASB_HUB_LOCATION-AksNodepools --resource-group $ASB_RG_HUB --add ipAddresses "$ASB_SPOKE_IP_PREFIX.0.0/22"

# Get spoke vnet id
export ASB_SPOKE_VNET_ID=$(az deployment group show -g $ASB_RG_SPOKE -n spoke-$ASB_ORG_APP_ID_NAME --query properties.outputs.clusterVnetResourceId.value -o tsv)

# TODO Add instructions to update Hub Firewall Policy Network Rules to allow AzureCloud.{location} - for now set them manually on Azure Portal 
```

## Deploy Azure Kubernetes Service

```bash
# Validate that you are using desired spoke network and orgId. Refer to network setup instructions to get correct values.
echo $ASB_SPOKE_VNET_ID
echo $ASB_ORG_APP_ID_NAME

# Check Log Analytics variable is set
echo $ASB_LA_NAME

# Set cluster locations by choosing the closest pair - not all regions support ASB. Make sure there has not been a cluster to this region before.
# Note: cluster location must be the same as spoke location
export ASB_CLUSTER_LOCATION=${ASB_SPOKE_LOCATION}
export ASB_CLUSTER_GEO_LOCATION=westcentralus


# Set top level domain
export ASB_DOMAIN=${ASB_DNS_NAME}-${ASB_SPOKE_LOCATION}.${ASB_DNS_ZONE}

# Add DNS A Record
az network private-dns record-set a add-record -g ${ASB_RG_CORE} -z ${ASB_DNS_ZONE} -n ${ASB_DNS_NAME}-${ASB_SPOKE_LOCATION} -a ${ASB_SPOKE_IP_PREFIX}.4.4

# Add Virtual Network Link to Private DNS zones
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z ${ASB_DNS_ZONE}
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z privatelink.azurecr.io
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z privatelink.vaultcore.azure.net
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z privatelink.documents.azure.com



# This section takes 15-20 minutes

# Create AKS
az deployment group create -g $ASB_RG_CORE \
  -f cluster/cluster-stamp-additional.json \
  -n cluster-${ASB_DEPLOYMENT_NAME}-$ASB_CLUSTER_LOCATION \
  -p location=${ASB_CLUSTER_LOCATION} \
     asbDomain=${ASB_DOMAIN} \
     clusterAdminAadGroupObjectId=${ASB_CLUSTER_ADMIN_ID} \
     coreResourceGroup=${ASB_RG_CORE} \
     deploymentName=${ASB_DEPLOYMENT_NAME} \
     geoRedundancyLocation=${ASB_CLUSTER_GEO_LOCATION} \
     k8sControlPlaneAuthorizationTenantId=${ASB_TENANT_ID} \
     kubernetesVersion=${ASB_K8S_VERSION} \
     laWorkspaceName=${ASB_LA_NAME} \
     nodepoolsRGName=${ASB_RG_NAME} \
     orgAppId=${ASB_ORG_APP_ID_NAME} \
     targetVnetResourceId=${ASB_SPOKE_VNET_ID} \
  -c --query name

# Grant PullFromACR permission
export ASB_ACR_RESOURCE_ID=$(az acr show -n $ASB_ACR_NAME -g $ASB_RG_CORE --query id -o tsv)

export ASB_CLUSTER_AGENTPOOL_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-$ASB_CLUSTER_LOCATION --query properties.outputs.aksClusterName.value -o tsv)-agentpool

export ASB_CLUSTER_AGENTPOOL_RESOURCE_ID=$(az identity show -n $ASB_CLUSTER_AGENTPOOL_NAME -g $ASB_RG_CORE-nodepools-$ASB_CLUSTER_LOCATION --query principalId -o tsv)

az role assignment create --role "AcrPull" --assignee ${ASB_CLUSTER_AGENTPOOL_RESOURCE_ID} --scope ${ASB_ACR_RESOURCE_ID}

# Set public ip address resource name
export ASB_PIP_NAME='pip-'$ASB_DEPLOYMENT_NAME'-'$ASB_ORG_APP_ID_NAME'-00'

# Get the public ip of our App gateway
export ASB_AKS_PIP=$(az network public-ip show -g $ASB_RG_SPOKE --name $ASB_PIP_NAME --query ipAddress -o tsv)

./saveenv.sh -y
```

### AKS Validation

```bash
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
```

## Create DNS A record

```bash
az network dns record-set a add-record -g $ASB_DNS_ZONE_RG -z $ASB_DNS_ZONE -n $ASB_DNS_NAME-$ASB_CLUSTER_LOCATION -a $ASB_AKS_PIP --query fqdn
```

## Create Deployment Files

Follow deployment instructions in the readme located [here](../README.md#create-deployment-files)
