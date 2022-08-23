# Spike: Deploying Thanos in a multi-cluster setup

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

#### Set name for the Observer cluster
export AZURE_OBSERVER_CLUSTER_NAME=thanos-01

#### Create the AKS Observer Cluster
az aks create -g $AZURE_RG_NAME \
  -n $AZURE_OBSERVER_CLUSTER_NAME \
  --node-count 3 \
  --generate-ssh-keys
  --location $AZURE_LOCATION

#### Connect to the AKS cluster
az aks get-credentials --resource-group $AZURE_RG_NAME --name $AZURE_OBSERVER_CLUSTER_NAME
```

### Create Azure Storage Account

```bash

#### Check if storage account name is available and is a valid name
export AZURE_STORAGE_ACCOUNT_NAME=<desired account name>
az storage account check-name --name $AZURE_STORAGE_ACCOUNT_NAME

#### Create storage account
az storage account create --name $AZURE_STORAGE_ACCOUNT_NAME --resource-group $AZURE_RG_NAME --location $AZURE_LOCATION

#### Retrieve Storage account access key
export AZURE_STORAGE_ACCOUNT_KEY=$(az storage account keys list -g $AZURE_RG_NAME -n $AZURE_STORAGE_ACCOUNT_NAME --query [0].value -o tsv)

##### Create Storage Container for Thanos
az storage container create --name metrics --account-name $AZURE_STORAGE_ACCOUNT_NAME --account-key $AZURE_STORAGE_ACCOUNT_KEY


```

### Install Prometheus + Thanos Sidecar for Observer Cluster

```bash
##### Create Monitoring Namespace
kubectl create ns monitoring

##### Generate secret config  from template
envsubst < spikes/thanos/manifests/template/thanos-storage-config.yaml.tmpl > spikes/thanos/manifests/thanos-storage-config.yaml

##### Create secret used by Thanos
kubectl create secret generic thanos-objstore-config \
  --from-file=spikes/thanos/manifests/thanos-storage-config.yaml \
  -n monitoring

#### Deploy prometheus + thanos sidecar
kubectl apply -f spikes/thanos/manifests/observer/prometheus/prometheus.yaml 

#### Verify monitoring pods are running
kubectl get pods -n monitoring

```

### Install Thanos Components for Observer Cluster

```bash

##### Thanos Querier is the layer that will allow us to query all Prometheus instances at once. It needs a Deployment that will be pointed to all sidecars, and it also needs its own Service to be able to be discovered and used.
kubectl apply -f spikes/thanos/manifests/observer/thanos/thanos-querier.yaml

##### Thanos Store runs along with the Querier to bring the data from our Object Storage to the queries. It’s composed of a StatefulSet, and a configuration that contains the configuration for the Store, which we previously created as a secret.
kubectl apply -f spikes/thanos/manifests/observer/thanos/thanos-store.yaml

##### Thanos compactor is the service that will downsample the historical data. It’s recommended when you have a lot of incoming data in order to reduce the storage requirements. Just like the Querier component, it is composed of a StatefulSet and a Service. It takes configurations like the Store.
kubectl apply -f spikes/thanos/manifests/observer/thanos/thanos-compactor.yaml

##### NGSA
kubectl create ns ngsa
kubectl apply -f spikes/thanos/manifests/observer/ngsa/ngsa.yaml

##### LR
kubectl create ns loderunner
kubectl apply -f spikes/thanos/manifests/observer/ngsa/loderunner.yaml

##### Grafana
kubectl apply -f spikes/thanos/manifests/observer/grafana/grafana.yaml -n monitoring

# In Grafana , Add Prometheus data source pointed to: http://thanos-query.monitoring.svc.cluster.local:10902
# Import dashboard in /spikes/thanos/manifests/observer/grafana/ngsa.json

```

## Deploy Observee Cluster

```bash

#### Set the name of your new resource group in Azure.
export AZURE_LOCATION=eastus

#### Set name for observee cluster
export AZURE_OBSERVEE_CLUSTER_NAME=thanos-02

#### Create the AKS Observer Cluster
az aks create -g $AZURE_RG_NAME \
  -n $AZURE_OBSERVEE_CLUSTER_NAME \
  --node-count 3 \
  --generate-ssh-keys \
  --location $AZURE_LOCATION

#### Connect to the AKS cluster
az aks get-credentials --resource-group $AZURE_RG_NAME --name $AZURE_OBSERVEE_CLUSTER_NAME

```

### Install Prometheus + Thanos Sidecar for Observee Cluster

```bash

##### Create Monitoring Namespace
kubectl create ns monitoring

##### Create secret used by Thanos
kubectl create secret generic thanos-objstore-config \
  --from-file=spikes/thanos/manifests/thanos-storage-config.yaml \
  -n monitoring

#### Deploy prometheus + thanos sidecar
kubectl apply -f spikes/thanos/manifests/observee/prometheus/prometheus.yaml 

#### Verify monitoring pods are running
kubectl get pods -n monitoring

##### NGSA
kubectl create ns ngsa
kubectl apply -f spikes/thanos/manifests/observee/ngsa/ngsa.yaml

##### LR
kubectl create ns loderunner
kubectl apply -f spikes/thanos/manifests/observee/ngsa/loderunner.yaml

##### Add observee cluster to the observer's querier

# Change context to observer cluster
az aks get-credentials --resource-group $AZURE_RG_NAME --name $AZURE_OBSERVER_CLUSTER_NAME

# IMPORTANT: Manually add a store to the observer's querier to include the OBSERVEE external IP address/ For example: --store=20.232.248.146:10901 and re apply
kubectl apply -f spikes/thanos/manifests/observer/thanos/thanos-querier.yaml


# Congrats! now you can access the Grafana Dashboards and see your metrics flowing

```
