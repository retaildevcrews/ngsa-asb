 # NGSA AKS Secure Baseline Pre-Prod deployment

> Welcome to the Patterns and Practices (PnP) AKS Secure Baseline (ASB)

- The Patterns and Practices AKS Secure Baseline repo is located [here](https://github.com/mspnp/aks-secure-baseline)
  - Please refer to the PnP repo as the `upstream repo`
  - Please use Codespaces

## Deploying ASB

```bash

🛑 Run these commands one at a time

# login to your Azure subscription
az login --use-device-code

# verify the correct subscription
# use az account set -s <sub> to change the sub if required
# you must be the owner of the subscription
# tenant ID should be 72f988bf-86f1-41af-91ab-2d7cd011db47 
az account show -o table

```

### Verify the security group

```bash

# set your security group name
export ASB_CLUSTER_ADMIN_GROUP=4-co

# verify you are a member of the security group
# if you are not a member, please request access

# Might need to execute this line if nested groups exist. 
az ad group member list -g $ASB_CLUSTER_ADMIN_GROUP  --query [].displayName -o table

```

### Set Deployment Short Name

> Deployment Name is used in resource naming to provide unique names

- Deployment Name is very particular and won't fail for about an hour ...
  - we recommend a short a name to total length of 8 or less
  - must be lowercase
  - must start with a-z
  - must only be a-z or 0-9
  - max length is 8
  - min length is 3

```bash

🛑 Set your deployment name per the above rules

#### set the depoyment name
# export ASB_DEPLOYMENT_NAME=[starts with a-z, [a-z,0-9], max length 8]

export ASB_DEPLOYMENT_NAME=[e.g 'ngsatest']
export ASB_DNS_NAME=[e.g 'ngsa-pre-central-asb-test']
export ASB_RG_NAME=[e.g 'ngsa-pre-central-asb-test']

```

```bash

# make sure the resource group doesn't exist
az group list -o table | grep $ASB_DEPLOYMENT_NAME

# make sure the branch doesn't exist
git branch -a | grep $ASB_DEPLOYMENT_NAME

# if either exists, choose a different team name and try again

```

🛑 Set Org App ID

```bash

# Org App ID e.g BU0001A0008
# export ASB_ORG_APP_ID_NAME=[starts with a-z, [a-z,0-9], min length 5, max length 11]
export ASB_ORG_APP_ID_NAME="BU0001G0001"

```

### Create git branch

```bash

# create a branch for your cluster
# Do not change the branch name from $ASB_DEPLOYMENT_NAME
git checkout -b $ASB_DEPLOYMENT_NAME
git push -u origin $ASB_DEPLOYMENT_NAME

```

### Choose your deployment region

```bash

🛑 Only choose one pair from the below block

### Set for deployment of resources. Cluster region will be set in a different step
export ASB_HUB_LOCATION=centralus
export ASB_SPOKE_LOCATION=centralus


```

### Save your work in-progress

```bash

# install kubectl and kubelogin
sudo az aks install-cli

# run the saveenv.sh script at any time to save ASB_* variables to ASB_DEPLOYMENT_NAME.asb.env

./saveenv.sh -y

# if your terminal environment gets cleared, you can source the file to reload the environment variables
# source ${ASB_DEPLOYMENT_NAME}.asb.env

```

### Setup AKS Secure Baseline

> Complete setup takes about an hour

#### Validate env vars

```bash

# validate team name is set up
echo $ASB_DEPLOYMENT_NAME

# verify the correct subscription
az account show -o table

🛑 # These env vars are already set in Codespaces enviroment for "cse.ms"

# check certs
if [ -z $APP_GW_CERT_CSMS ]; then echo "App Gateway cert not set correctly"; fi
if [ -z $INGRESS_CERT_CSMS ]; then echo "Ingress cert not set correctly"; fi
if [ -z $INGRESS_KEY_CSMS ]; then echo "Ingress key not set correctly"; fi

```

#### AAD

```bash

# get AAD cluster admin group
export ASB_CLUSTER_ADMIN_ID=$(az ad group show -g $ASB_CLUSTER_ADMIN_GROUP --query objectId -o tsv)

# verify AAD admin group
echo $ASB_CLUSTER_ADMIN_GROUP
echo $ASB_CLUSTER_ADMIN_ID

```

#### Set variables for deployment

```bash

# set GitOps repo
export ASB_GIT_REPO=$(git remote get-url origin)
export ASB_GIT_BRANCH=$ASB_DEPLOYMENT_NAME
export ASB_GIT_PATH=deploy/$ASB_DEPLOYMENT_NAME

# set default domain name
export ASB_DNS_ZONE=cse.ms
export ASB_DOMAIN=${ASB_DNS_NAME}.${ASB_DNS_ZONE}

# resource group names
export ASB_RG_CORE=rg-${ASB_RG_NAME}
export ASB_RG_HUB=rg-${ASB_RG_NAME}-hub
export ASB_RG_SPOKE=rg-${ASB_RG_NAME}-spoke

# export AAD env vars
export ASB_TENANT_ID=$(az account show --query tenantId -o tsv)

# save env vars
./saveenv.sh -y


```

#### Create Resource Groups

```bash

# create the resource groups
az group create -n $ASB_RG_CORE -l $ASB_HUB_LOCATION
az group create -n $ASB_RG_HUB -l $ASB_HUB_LOCATION
az group create -n $ASB_RG_SPOKE -l $ASB_SPOKE_LOCATION


```

#### Setup Network for the first time

```bash
# this section takes 15-20 minutes to complete

# create hub network
az deployment group create -g $ASB_RG_HUB -f networking/hub-default.json -p location=${ASB_HUB_LOCATION} -c --query name
export ASB_VNET_HUB_ID=$(az deployment group show -g $ASB_RG_HUB -n hub-default --query properties.outputs.hubVnetId.value -o tsv)

# Create your spoke deployment file 
cp networking/spoke-BU0001A0008.json networking/spoke-$ASB_ORG_APP_ID_NAME.json

# Set Spoke IP address prefix
export ASB_SPOKE_IP_PREFIX="10.240"

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

# create Region A hub network
az deployment group create -g $ASB_RG_HUB -f networking/hub-regionA.json -p location=${ASB_HUB_LOCATION} nodepoolSubnetResourceIds="['${ASB_NODEPOOLS_SUBNET_ID}']" -c --query name
export ASB_SPOKE_VNET_ID=$(az deployment group show -g $ASB_RG_SPOKE -n spoke-$ASB_ORG_APP_ID_NAME --query properties.outputs.clusterVnetResourceId.value -o tsv)

./saveenv.sh -y

```

#### Setup AKS

```bash

# Validate that you are using the correct vnet for cluster deployment
echo $ASB_SPOKE_VNET_ID
echo $ASB_ORG_APP_ID_NAME

# Set cluster location by choosing the closest pair - not all regions support ASB.
# Note: cluster location must be the same as spoke location
export ASB_CLUSTER_LOCATION=${ASB_SPOKE_LOCATION}
export ASB_CLUSTER_GEO_LOCATION=westus

### this section takes 15-20 minutes

# Set Kubernetes Version
export ASB_K8S_VERSION=1.20.9

# Create AKS
az deployment group create -g $ASB_RG_CORE \
  -f cluster-stamp.json \
  -n cluster-${ASB_DEPLOYMENT_NAME} \
  -p location=${ASB_CLUSTER_LOCATION} \
     geoRedundancyLocation=${ASB_CLUSTER_GEO_LOCATION} \
     deploymentName=${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} \
     orgAppId=${ASB_ORG_APP_ID_NAME} \
     nodepoolsRGName=${ASB_RG_NAME} \
     asbDnsName=${ASB_DNS_NAME}-${ASB_CLUSTER_LOCATION} \
     asbDomain=${ASB_DOMAIN} \
     asbDnsZone=${ASB_DNS_ZONE} \
     targetVnetResourceId=${ASB_SPOKE_VNET_ID} \
     hubVnetResourceId=${ASB_VNET_HUB_ID} \
     clusterAdminAadGroupObjectId=${ASB_CLUSTER_ADMIN_ID} \
     k8sControlPlaneAuthorizationTenantId=${ASB_TENANT_ID} \
     appGatewayListenerCertificate=${APP_GW_CERT_CSMS} \
     aksIngressControllerCertificate="$(echo $INGRESS_CERT_CSMS | base64 -d)" \
     aksIngressControllerKey="$(echo $INGRESS_KEY_CSMS | base64 -d)" \
     kubernetesVersion=${ASB_K8S_VERSION} \
     -c --query name 
```

#### Set AKS env vars

```bash
# set public ip address resource name
export ASB_PIP_NAME='pip-'$ASB_DEPLOYMENT_NAME'-'$ASB_ORG_APP_ID_NAME'-00'

# get the name of the deployment key vault
export ASB_KV_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.keyVaultName.value -o tsv)

# get cluster name
export ASB_AKS_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.aksClusterName.value -o tsv)

# Get the public IP of our App gateway
export ASB_AKS_PIP=$(az network public-ip show -g $ASB_RG_SPOKE --name $ASB_PIP_NAME --query ipAddress -o tsv)

# Get the AKS Ingress Controller Managed Identity details.
export ASB_ISTIO_RESOURCE_ID=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.aksIngressControllerPodManagedIdentityResourceId.value -o tsv)
export ASB_ISTIO_CLIENT_ID=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.aksIngressControllerPodManagedIdentityClientId.value -o tsv)
export ASB_POD_MI_ID=$(az identity show -n podmi-ingress-controller -g $ASB_RG_CORE --query principalId -o tsv)

# Get the name of Azure Container Registry
export ASB_ACR_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION}  --query properties.outputs.containerRegistryName.value -o tsv)

# config certs
export ASB_INGRESS_CERT_NAME=appgw-ingress-internal-aks-ingress-tls
export ASB_INGRESS_KEY_NAME=appgw-ingress-internal-aks-ingress-key

./saveenv.sh -y

```

### Create setup files

```bash

mkdir -p $ASB_GIT_PATH/istio

# istio pod identity config
cat templates/istio-pod-identity.yaml | envsubst > $ASB_GIT_PATH/istio/istio-pod-identity-config.yaml

# istio gateway config
cat templates/istio-gateway.yaml | envsubst > $ASB_GIT_PATH/istio/istio-gateway.yaml

# GitOps (flux)
mkdir -p $ASB_GIT_PATH/flux
cat templates/flux.yaml | envsubst  > $ASB_GIT_PATH/flux/flux.yaml

```

### Push to GitHub
> The setup process creates 4 new files
>
> GitOps will not work unless these files are merged into your branch

```bash

# check deltas - there should be 4 new files
git status

# push to your branch
git add $ASB_GIT_PATH

git commit -m "added cluster config"
git push

```

### Create a DNS A record

```bash
# We are using 'dns-rg' for triplets

# resource group of DNS Zone for deployment
export ASB_DNS_ZONE_RG=dns-rg 

# create the dns record
az network dns record-set a add-record -g $ASB_DNS_ZONE_RG -z $ASB_DNS_ZONE -n $ASB_DNS_NAME-$ASB_SPOKE_LOCATION -a $ASB_AKS_PIP --query fqdn

```

### AKS Validation

```bash

# get AKS credentials
az aks get-credentials -g $ASB_RG_CORE -n $ASB_AKS_NAME

# rename context for simplicity
kubectl config rename-context $ASB_AKS_NAME $ASB_DEPLOYMENT_NAME

# check the nodes
# requires Azure login
kubectl get nodes

# check the pods
kubectl get pods -A

### Congratulations!  Your AKS Secure Baseline cluster is running!

```

### Deploy Flux

> ASB uses `Flux CD` for `GitOps`

```bash

# setup flux
kubectl apply -f $ASB_GIT_PATH/flux/flux.yaml

# 🛑 check the pods until everything is running
kubectl get pods -n flux-cd -l app.kubernetes.io/name=flux

# check flux logs
kubectl logs -n flux-cd -l app.kubernetes.io/name=flux

# copy bootstrap files needed
cp -r templates/bootstrap deploy

# push to your branch
git add deploy

git commit -m "added cluster config"
git push

```

## Deploying NGSA Applications

### 🛑 Prerequisite - [Setup Cosmos DB in secure baseline](./docs/cosmos.md)

There are two different options to choose from for deploying NGSA:
- [Deploy using yaml with FluxCD](./docs/deployNgsaYaml.md)
- [Deploy using AutoGitops with FluxCD](./docs/deployNgsaAgo.md)



### Deploy Fluent Bit

```bash
# Import image into ACR
az acr import --source docker.io/fluent/fluent-bit:1.5 -n $ASB_ACR_NAME

# Create namespace
kubectl create ns fluentbit

export ASB_LA_WORKSPACE_NAME=la-$ASB_AKS_NAME

# Create secrets to authenticate with log analytics
kubectl create secret generic fluentbit-secrets --from-literal=WorkspaceId=$(az monitor log-analytics workspace show -g $ASB_RG_CORE -n $ASB_LA_WORKSPACE_NAME --query customerId -o tsv)   --from-literal=SharedKey=$(az monitor log-analytics workspace get-shared-keys -g $ASB_RG_CORE -n $ASB_LA_WORKSPACE_NAME --query primarySharedKey -o tsv) -n fluentbit

# Load required yaml

mkdir $ASB_GIT_PATH/fluentbit

cat templates/fluentbit/config-log.yaml | envsubst > $ASB_GIT_PATH/fluentbit/config-log.yaml

cat templates/fluentbit/daemonset.yaml | envsubst > $ASB_GIT_PATH/fluentbit/daemonset.yaml

cp templates/fluentbit/config.yaml $ASB_GIT_PATH/fluentbit

cp templates/fluentbit/role.yaml  $ASB_GIT_PATH/fluentbit

git add $ASB_GIT_PATH/fluentbit

git commit -m "added fluentbit"

git push

# Sync Flux
fluxctl sync --k8s-fwd-ns flux-cd

```

### Deploy Grafana and Prometheus

Please see Instructions to deploy Grafana and Prometheus [here](./monitoring/README.md)


### Resetting the cluster

> Reset the cluster to a known state
>
> This is normally signifcantly faster for inner-loop development than recreating the cluster

```bash

# delete the namespaces
# this can take 4-5 minutes
### order matters as the deletes will hang and flux could try to re-deploy
kubectl delete ns flux-cd
kubectl delete ns ngsa
kubectl delete ns istio-system
kubectl delete ns istio-operator
kubectl delete ns cluster-baseline-settings

# check the namespaces
kubectl get ns

# start over at Deploy Flux

```

### Running Multiple Clusters

- start a new shell to clear the ASB_* env vars
- start at `Set Team Name`
- make sure to use a new ASB_DEPLOYMENT_NAME
- you must create a new branch or GitOps will fail on both clusters

## Delete Azure Resources

> Do not just delete the resource groups

Make sure ASB_DEPLOYMENT_NAME is set correctly

```bash

echo $ASB_DEPLOYMENT_NAME

```

Delete the cluster

```bash

# resource group names
export ASB_RG_CORE=rg-${ASB_RG_NAME}
export ASB_RG_HUB=rg-${ASB_RG_NAME}-hub
export ASB_RG_SPOKE=rg-${ASB_RG_NAME}-spoke

export ASB_AKS_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME} --query properties.outputs.aksClusterName.value -o tsv)
export ASB_KEYVAULT_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME} --query properties.outputs.keyVaultName.value -o tsv)
export ASB_LA_HUB=$(az monitor log-analytics workspace list -g $ASB_RG_HUB --query [0].name -o tsv)

# delete and purge the key vault
az keyvault delete -n $ASB_KEYVAULT_NAME
az keyvault purge -n $ASB_KEYVAULT_NAME

# hard delete Log Analytics
az monitor log-analytics workspace delete -y --force true -g $ASB_RG_CORE -n la-${ASB_AKS_NAME}
az monitor log-analytics workspace delete -y --force true -g $ASB_RG_HUB -n $ASB_LA_HUB

# delete the resource groups
az group delete -y --no-wait -g $ASB_RG_CORE
az group delete -y --no-wait -g $ASB_RG_HUB
az group delete -y --no-wait -g $ASB_RG_SPOKE

# delete from .kube/config
kubectl config delete-context $ASB_DEPLOYMENT_NAME

# group deletion can take 10 minutes to complete
az group list -o table | grep $ASB_DEPLOYMENT_NAME

### sometimes the spokes group has to be deleted twice
az group delete -y --no-wait -g $ASB_RG_SPOKE

```

```bash
## Delete git branch

git checkout main
git pull
git push origin --delete $ASB_DEPLOYMENT_NAME
git fetch -pa
git branch -D $ASB_DEPLOYMENT_NAME

```

### Random Notes

```bash

# stop your cluster
az aks stop --no-wait -n $ASB_AKS_NAME -g $ASB_RG_CORE
az aks show -n $ASB_AKS_NAME -g $ASB_RG_CORE --query provisioningState -o tsv

# start your cluster
az aks start --no-wait --name $ASB_AKS_NAME -g $ASB_RG_CORE
az aks show -n $ASB_AKS_NAME -g $ASB_RG_CORE --query provisioningState -o tsv

# disable policies (last resort for debugging)
az aks disable-addons --addons azure-policy -g $ASB_RG_CORE -n $ASB_AKS_NAME

# delete your AKS cluster (keep your network)
### TODO - this doesn't work completely
az deployment group delete -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}

```
