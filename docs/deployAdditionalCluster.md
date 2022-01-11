#### Adding additional spoke networks
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
  -g $ASB_RG_SPOKE \
  -f networking/spoke-$ASB_ORG_APP_ID_NAME.json \
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

```


#### Deploying Additional Clusters

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

# Add DNS A Record
az network private-dns record-set a add-record -g ${ASB_RG_CORE} -z ${ASB_DNS_ZONE} -n ${ASB_RG_NAME}-${ASB_SPOKE_LOCATION} -a ${ASB_SPOKE_IP_PREFIX}.4.4

# Add Virtual Network Link to Private DNS zones
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z ${ASB_DNS_ZONE}
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z privatelink.azurecr.io
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z privatelink.vaultcore.azure.net
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z privatelink.documents.azure.com


# Get App Gateway frontend MI ID
export ASB_FRONTEND_MI_ID=$(az identity show -n mi-appgateway-frontend -g $ASB_RG_CORE --query id -o tsv)


### this section takes 15-20 minutes

# Create AKS
az deployment group create -g $ASB_RG_CORE \
  -f cluster-stamp-additional.json \
  -n cluster-${ASB_DEPLOYMENT_NAME}-$ASB_CLUSTER_LOCATION \
  -p location=${ASB_CLUSTER_LOCATION} \
     geoRedundancyLocation=${ASB_CLUSTER_GEO_LOCATION} \
     nodepoolsRGName=${ASB_RG_NAME} \
     targetVnetResourceId=${ASB_SPOKE_VNET_ID} \
     clusterAdminAadGroupObjectId=${ASB_CLUSTER_ADMIN_ID} \
     k8sControlPlaneAuthorizationTenantId=${ASB_TENANT_ID} \
     laWorkspaceName=${ASB_LA_NAME} \
     laResourceGroup=${ASB_RG_CORE} \
     frontEndMiResourceId=${ASB_FRONTEND_MI_ID} \
     kubernetesVersion=${ASB_K8S_VERSION} \
     --query name -c

# Grant PullFromACR permission
export ASB_ACR_RESOURCE_ID=$(az acr show -n $ASB_ACR_NAME -g $ASB_RG_CORE --query id -o tsv)
export ASB_CLUSTER_AGENTPOOL_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-$ASB_CLUSTER_LOCATION --query properties.outputs.aksClusterName.value -o tsv)-agentpool
export ASB_CLUSTER_AGENTPOOL_RESOURCE_ID=$(az identity show -n $ASB_CLUSTER_AGENTPOOL_NAME -g $ASB_RG_CORE-nodepools-$ASB_CLUSTER_LOCATION --query principalId -o tsv)
az role assignment create --role "AcrPull" --assignee ${ASB_CLUSTER_AGENTPOOL_RESOURCE_ID} --scope ${ASB_ACR_RESOURCE_ID}


```