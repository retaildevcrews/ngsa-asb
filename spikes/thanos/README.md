# Spike: Deploying Thanos

The following instructions provide a basic implementation of AKS + Thanos for LTS

## Azure login

Log in to the Azure subscription

```bash
export AZURE_SUBSCRIPTION_ID=<yourSubscriptionId>

az login --use-device-code

az account set --subscription $AZURE_SUBSCRIPTION_ID

#### Verify you are in the correct subscription and you are the owner
az account show -o table
```

## Deploy Observer Cluster

```bash

#### Set the name of your new resource group in Azure.
export AZURE_RG_NAME=aks-thanos-spike
export AZURE_LOCATION=southcentralus

#### Check if the resource group name is not already in use
az group list -o table | grep $AZURE_RG_NAME

#### Create the new resource group
az group create -n $AZURE_RG_NAME -l $AZURE_LOCATION

#### Set name for management cluster
export AZURE_OBSERVER_CLUSTER_NAME=thanos-observer

#### Create the AKS Observer Cluster
az aks create -g $AZURE_RG_NAME \
  -n $AZURE_OBSERVER_CLUSTER_NAME \
  --node-count 3 \
  --generate-ssh-keys

#### Connect to the AKS cluster
az aks get-credentials --resource-group $AZURE_RG_NAME --name $AZURE_OBSERVER_CLUSTER_NAME
```

### Create Azure Storage Account

```bash

#### Check if storage account name is available
export AZURE_STORAGE_ACCOUNT_NAME=<desired account name>
az storage account check-name --name $AZURE_STORAGE_ACCOUNT_NAME

#### Create storage account
az storage account create --name $AZURE_STORAGE_ACCOUNT_NAME --resource-group $AZURE_RG_NAME --location $AZURE_LOCATION

#### Retrieve Storage account access key
export AZURE_STORAGE_ACCOUNT_KEY=$(az storage account keys list -g $AZURE_RG_NAME -n $AZURE_STORAGE_ACCOUNT_NAME --query [0].value -o tsv)

##### Create Storage Container for Thanos
az storage container create --name metrics --account-name $AZURE_STORAGE_ACCOUNT_NAME --account-key $AZURE_STORAGE_ACCOUNT_KEY

```

### Install Prometheus + Thanos Query

```bash
##### Create Monitoring Namespace
kubectl create ns monitoring

##### Create secret used by Thanos TODO: Convert to template using envsubst
kubectl create secret generic thanos-objstore-config \
  --from-file=spikes/thanos/manifests/thanos-storage-config.yaml \
  -n monitoring

#### Add prometheus-community Helm Repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

#### Install kube-prometheus-stack
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --values spikes/thanos/manifests/prometheus-values.yaml

helm template vault hashicorp/vault --output-dir vault-manifests/helm-manifests

#### Verify monitoring pods are running
kubectl get pods -n monitoring

```

### Install Thanos Components

```bash

##### Thanos Querier is the layer that will allow us to query all Prometheus instances at once. It needs a Deployment that will be pointed to all sidecars, and it also needs its own Service to be able to be discovered and used.
kubectl apply -f spikes/thanos/manifests/thanos-querier.yaml 

##### Thanos Store runs along with the Querier to bring the data from our Object Storage to the queries. It’s composed of a StatefulSet, and a configuration that contains the configuration for the Store, which we previously created as a secret.
kubectl apply -f spikes/thanos/manifests/thanos-store.yaml

##### Thanos compactor is the service that will downsample the historical data. It’s recommended when you have a lot of incoming data in order to reduce the storage requirements. Just like the Querier component, it is composed of a StatefulSet and a Service. It takes configurations like the Store.
kubectl apply -f spikes/thanos/manifests/thanos-compactor.yaml
```