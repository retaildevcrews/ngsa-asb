
# OpenSearch Deployment

## Deploy Opensearch in Azure ASB Cluster

> The steps below are guidelines for the dev cluster, but is replicable for the pre-prod as well

# TODO: set up instructions and prerequisites for dns, firewall, appgateway, etc.

Now we need to make sure our cluster can pull the required container images.
We will push OpenSearch-operator and kube-rbac-proxy images into our cluster's private ACR repo
  (e.g. `rg-wcnp-dev/acraksjxdthrti3j3qu`).

* Goto your private ACR instance, and click on `Networking`
* Check `Add your client IP address` and save
  * This will add your machine's IP addr which will enable you to view and
    push registries into this ACR.
* Now we push all required Harbor images to the ACR with `az acr import`.

  ```bash
  # Select proper subscription for your ACR and login to the account
  az account set -s "MCAPS-43649-AUS-DEVCREWS" --output table
  az login --scope https://management.core.windows.net//.default

  # Now push images to ACR
  # Here we're using acraksjxdthrti3j3qu
  az acr import --source gcr.io/kubebuilder/kube-rbac-proxy:v0.8.0 -n acraksjxdthrti3j3qu
  
  # Opensearch Operator
  az acr import --source public.ecr.aws/opsterio/opensearch-operator:2.2.1 -n acraksjxdthrti3j3qu
  # InitHelper
  az acr import --source public.ecr.aws/opsterio/busybox:1.27.2-buildx -n acraksjxdthrti3j3qu

  # NOTE: 
  # During the spike execution I was not able to import either the "opensearch-operator" or "busybox" images directly due to an unknown 'Error copying blobs' related issue. 

  # As a workaround I pulled the images locally then pushed them manually to Acr, if so, the current logged in user needs to have "acr push" permission and needs to login to the acr e.g. 'az acr login --name acraksjxdthrti3j3qu'

  ```

## Custom init helper

During cluster initialization the operator uses init containers as helpers. For these containers a busybox image is used ( specifically public.ecr.aws/opsterio/busybox:1.27.2-buildx). Since we are working in an offline environment we need to import the image into Acr, however I face the same 'Error copying blobs' issue, and them the same workearound was utilizes, manually pulled the image and pushed it to Acr, in the similar way we did it for 'opensearch-operator'.

The 'opensearch-cluster.yaml' file already was updated to pull the from Acr instead by overriding the initHelper.

## AKS Compliace 'Temporary' Updates

> * Updating policy assignment 'Kubernetes cluster containers should only use allowed images' to allow '|docker.io/opensearchproject/opensearch.+$'
> * Updating policy assignment 'Kubernetes cluster containers CPU and memory resource limits should not exceed the specified limits' to allow images
  >   - 'acraksjxdthrti3j3qu.azurecr.io/opsterio/busybox:1.27.2-buildx'
  >   - 'docker.io/opensearchproject/opensearch:latest'


Now that all of the setup is done, we're ready to deploy:

# Opensearch Operator [User Guide](https://github.com/Opster/opensearch-k8s-operator/blob/main/docs/userguide/main.md)

## Install the OpenSearch Operator

```bash
# Assuming Heml is already installed and available.
# Assuming we're at REPO_ROOT

# Add OpenSearch helm repo and update
helm repo add opensearch-operator https://opster.github.io/opensearch-k8s-operator/

helm repo update

# Use Helm cli to list the open search repository to make sure it was added successfully.  
helm repo list | grep opensearch

# Install Chart
helm install -f spikes/opensearch/helm-values.yaml ngsa-opensearch-operator opensearch-operator/opensearch-operator --version 2.2.1 -n opensearch-operator-system --create-namespace

# Verify installation
kubectl get ns | grep opens

# Verify crds installation
kubectl get crd | grep opensearch

# Verify pod are up and running 

kubectl get pod -n opensearch-operator-system

```

## Install the Cluster

Note: Original file was copied from repo [opensearch-k8-operator](https://github.com/Opster/opensearch-k8s-operator/tree/main/opensearch-operator/examples)

```bash
# Create namespace and create cluster
kubectl apply -f spikes/opensearch/deploy/opensearch-cluster.yaml

# Verify the cluster was created
kubectl get opensearch -n opensearch

kubectl get pod -n opensearch

```


# TODO: configure TLS
https://github.com/Opster/opensearch-k8s-operator/blob/main/docs/userguide/main.md#tls

## Uninstall OpenSearch operator chart

```bash
helm uninstall ngsa-opensearch-operator -n opensearch
```

## Upgrade OpenSearch operator chart

```bash
helm upgrade ngsa-opensearch-operator opensearch-operator/opensearch-operator
```
