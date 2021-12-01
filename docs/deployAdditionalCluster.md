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

# Ensure correct hub location is set.
echo $ASB_HUB_LOCATION

# create spoke network
az deployment group create \
  -g $ASB_RG_SPOKE \
  -f networking/spoke-$ASB_ORG_APP_ID_NAME.json \
  -p spokeLocation=${ASB_SPOKE_LOCATION} \
     hubLocation=${ASB_HUB_LOCATION} \
     orgAppId=${ASB_ORG_APP_ID_NAME} \
     hubVnetResourceId="${ASB_VNET_HUB_ID}" \
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
export ASB_LA_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME} --query properties.outputs.logAnalyticsName.value -o tsv)

### Set cluster locations by choosing the closest pair - not all regions support ASB. Make sure there has not been a cluster to this region before.
# Note: cluster location must be the same as spoke location
export ASB_CLUSTER_LOCATION=${ASB_SPOKE_LOCATION}
export ASB_CLUSTER_GEO_LOCATION=westcentralus


# Update deployment name to ensure unique deployment
export ASB_DEPLOYMENT_NAME=$ASB_DEPLOYMENT_NAME-$ASB_CLUSTER_LOCATION


### this section takes 15-20 minutes

# Create AKS

az deployment group create -g $ASB_RG_CORE \
  -f cluster-stamp-additional.json \
  -n cluster-${ASB_DEPLOYMENT_NAME} \
  -p location=${ASB_CLUSTER_LOCATION} \
     geoRedundancyLocation=${ASB_GEO_LOCATION} \
     orgAppId=${ASB_ORG_APP_ID_NAME} \
     nodepoolsRGName=${ASB_RG_NAME} \
     targetVnetResourceId=${ASB_SPOKE_VNET_ID} \
     clusterAdminAadGroupObjectId=${ASB_CLUSTER_ADMIN_ID} \
     k8sControlPlaneAuthorizationTenantId=${ASB_TENANT_ID} \
     appGatewayListenerCertificate=${APP_GW_CERT_CSMS} \
     aksIngressControllerCertificate="$(echo $INGRESS_CERT_CSMS | base64 -d)" \
     aksIngressControllerKey="$(echo $INGRESS_KEY_CSMS | base64 -d)" \
     laWorkspaceName=${ASB_LA_NAME} \
     laResourceGroup=${ASB_RG_CORE} \
     --query name -c

# Add DNS Record to Private DNS zone
az network private-dns record-set a add-record -g ${ASB_RG_CORE} -z ${ASB_DNS_ZONE} -n ${ASB_RG_NAME}-${ASB_SPOKE_LOCATION} -a ${ASB_SPOKE_IP_PREFIX}.4.4

# Add Virtual Network Link to Private DNS zone
az network private-dns link vnet create -n "to_vnet-spoke-$ASB_ORG_APP_ID_NAME-00" -e false -g ${ASB_RG_CORE} -v ${ASB_SPOKE_VNET_ID} -z ${ASB_DNS_ZONE}



```