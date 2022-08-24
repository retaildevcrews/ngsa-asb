# Spike: Deploying Cluster API with Cilium

The following instructions provide a basic implementation on how to setup Cluster API in an AKS cluster with Cilium CNI enabled.

## Prerequisites

- AZ CLI [download](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- kubectl [download](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- clusterctl [download](https://cluster-api.sigs.k8s.io/user/quick-start.html#install-clusterctl)
- cilium [download](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)

## Azure login

Log in to the Azure subscription used to deploy the management cluster.

```bash
export AZURE_SUBSCRIPTION_ID=<yourSubscriptionId>
az login --use-device-code
az account set --subscription $AZURE_SUBSCRIPTION_ID
```

## Create the Management Cluster using Azure Kubernetes Service (AKS)

To get started, you will need to create an AKS cluster that will manage the lifecycle of all your fleet clusters. For this setup we will be creating a vanilla AKS cluster with the Bring Your Own CNI (BYOCNI) feature enabled. This will help us install Cilium CNI.

```bash
# Set the name of your new resource group in Azure.
export AZURE_RG_NAME=capi-aks
export AZURE_LOCATION=southcentralus

# Check if the resource group name is not already in use
az group list -o table | grep $AZURE_RG_NAME

# Create the new resource group
az group create -n $AZURE_RG_NAME -l $AZURE_LOCATION

# Set name for management cluster
export AZURE_MGT_CLUSTER_NAME=capi-management

# Create the AKS Cluster with no CNI (this will take 5 to 10 minutes)
az aks create -g $AZURE_RG_NAME \
  -n $AZURE_MGT_CLUSTER_NAME \
  --node-count 1 \
  --generate-ssh-keys \
  --network-plugin none

# Connect to the AKS cluster
az aks get-credentials --resource-group $AZURE_RG_NAME --name $AZURE_MGT_CLUSTER_NAME
```

## Install Cilium CNI on Management Cluster

For the Nodepools to be in Ready state, a Container Network Interface(CNI) must be installed.

```bash
# Install Cilum CNI
cilium install --azure-resource-group $AZURE_RG_NAME

# Verify AKS nodes, they should be in Ready state
kubectl get nodes
```

## Initialize the Management Cluster with Cluster API

Now that the AKS cluster is created with Cilium, it needs to be initialized with Cluster API to become the management cluster. The management cluster allows you to control and maintain the fleet of worker clusters

```bash

# Enable support for managed topologies and experimental features
export CLUSTER_TOPOLOGY=true
export EXP_AKS=true
export EXP_MACHINE_POOL=true

# Create an Azure Service Principal in the Azure portal. (Note: Make sure this Service Principal has access to the resource group)

# # Create an Azure Service Principal
# export AZURE_SP_NAME="<ServicePrincipalName>"

# az ad sp create-for-rbac \
#   --name $AZURE_SP_NAME \
#   --role contributor \
#   --scopes="/subscriptions/${AZURE_SUBSCRIPTION_ID}"

export AZURE_TENANT_ID="<Tenant>"
export AZURE_CLIENT_ID="<AppId>"
export AZURE_CLIENT_SECRET="<Password>"

# Base64 encode the variables
export AZURE_SUBSCRIPTION_ID_B64="$(echo -n "$AZURE_SUBSCRIPTION_ID" | base64 | tr -d '\n')"
export AZURE_TENANT_ID_B64="$(echo -n "$AZURE_TENANT_ID" | base64 | tr -d '\n')"
export AZURE_CLIENT_ID_B64="$(echo -n "$AZURE_CLIENT_ID" | base64 | tr -d '\n')"
export AZURE_CLIENT_SECRET_B64="$(echo -n "$AZURE_CLIENT_SECRET" | base64 | tr -d '\n')"

# Settings needed for AzureClusterIdentity used by the AzureCluster
export AZURE_CLUSTER_IDENTITY_SECRET_NAME="cluster-identity-secret"
export CLUSTER_IDENTITY_NAME="cluster-identity"
export AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE="default"

# Create a secret to include the password of the Service Principal identity created in Azure
# This secret will be referenced by the AzureClusterIdentity used by the AzureCluster
kubectl create secret generic "${AZURE_CLUSTER_IDENTITY_SECRET_NAME}" --from-literal=clientSecret="${AZURE_CLIENT_SECRET}"

# Initialize the management cluster for azure
clusterctl init --infrastructure azure
```

## Patch Cluster API provider for Azure (CAPZ)

To have a Cilium CNI workload cluster deployed using Cluster API, the workload cluster must be BYOCNI supported. As of now this feature is not GA, so we will have to apply an experimental patch to support this.

```bash
# Install Custom CRD for Azure Managed Control Planes (--network-plugin none)
kubectl apply -f ./spikes/cluster-api-cilium/manifests/infrastructure.cluster.x-k8s.io_azuremanagedcontrolplanes.yaml 

# Update CAPZ deployment image for a custom forked image that supports BYOCNI
kubectl set image deployment/capz-controller-manager \
  manager=ghcr.io/retaildevcrews/cluster-api-azure-controller:beta \
  -n capz-system

# Wait for new capz-controller manager to be ready
watch kubectl get pods -n capz-system

```

## Deploy Worker Cluster and install Cilium CNI

```bash

#Apply the cluster manifest and inject variables
envsubst < <(cat spikes/cluster-api-cilium/manifests/workload-cluster01.yaml) | kubectl apply -f -

# Wait for cluster to be in Provisioned state (this will take 6 minutes)
watch kubectl get clusters

# Generate kubeconfig for cluster
mkdir -p kubeconfig
clusterctl get kubeconfig aks-southcentralus-cluster01 > kubeconfig/aks-southcentralus-cluster01.kubeconfig

# Check worker cluster nodes
KUBECONFIG=kubeconfig/aks-southcentralus-cluster01.kubeconfig kubectl get nodes

#Install Cilium
KUBECONFIG=kubeconfig/aks-southcentralus-cluster01.kubeconfig \
  cilium install \
  --azure-resource-group $AZURE_RG_NAME

# Verify Cilium installation
KUBECONFIG=kubeconfig/aks-southcentralus-cluster01.kubeconfig kubectl get nodes

KUBECONFIG=kubeconfig/aks-southcentralus-cluster01.kubeconfig cilium status

```
