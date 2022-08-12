# Deploy NGSA AKS Secure Baseline With Cilium

## Prerequisites

Follow ASB Setup Until [Resource Group Creation](/README.md#set-aks-environment-variables)

## Deploying Hub and Spoke Networks With Additional Access To Pull Cilium Images From quay.io

> Complete setup takes about an hour

```bash
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
  -f spikes/cilium/hub-regionA.json \
  -p location=${ASB_HUB_LOCATION} nodepoolSubnetResourceIds="['${ASB_NODEPOOLS_SUBNET_ID}']" \
  -c --query name

# Get spoke vnet id
export ASB_SPOKE_VNET_ID=$(az deployment group show -g $ASB_RG_SPOKE -n spoke-$ASB_ORG_APP_ID_NAME --query properties.outputs.clusterVnetResourceId.value -o tsv)

./saveenv.sh -y
```

## Deploy Azure Kubernetes Service With CNI Set To None

```bash
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

az extension add --name aks-preview

# Create AKS
az deployment group create -g $ASB_RG_CORE \
  -f spikes/cilium/cluster-stamp.json \
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

### Install Cilium CLI

More Installation Details Can Be Found on [cilium.io](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)

```bash

# Determine Installation Requirements
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi

# Download Cilium
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Install Cilium
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin

# Remove Unnecessary Installation Files
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
```

### Install Cilium CNI For AKS

```bash

cilium install --azure-resource-group "${ASB_RG_CORE}"

# This Can Take A Minute Or Longer
cilium status --wait

```

### Optional: Cilium Tests

Before running cilium connectivity tests, ensure to add both highlighted firewall rules to enable access to cloudflare's dns servers:

![Additional Cilium Network Rules](/spikes/cilium/additional-cilium-network-rules.png)

```bash

# Enable Hubble To For Testing
cilium hubble enable

# These should all pass
cilium connectivity test
```

### Next Steps

Continue [ASB Setup](/README.md#set-aks-environment-variables)
