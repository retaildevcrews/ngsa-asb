# AKS Secure Baseline Pre-Prod deployment

> Welcome to the Patterns and Practices (PnP) AKS Secure Baseline (ASB)

- The Patterns and Practices AKS Secure Baseline repo is located [here](https://github.com/mspnp/aks-secure-baseline)
  - Please refer to the PnP repo as the `upstream repo`

## Deploying ASB

<!-- 
### Create Codespace

> The OpenHack requires Codespaces and bash
> If you have dotfiles that default to zsh, make sure to use bash as your terminal

- The `AKS Secure Baseline` repo for the OpenHack is at [github/retaildevcrews/asb-spark](https://github.com/retaildevcrews/asb-spark)
- Open this repo in your web browser
- Create a new `Codespace` in this repo
  - If the `fork option` appears, you need to request permission to the repo
  - Do not choose fork -->

```bash

🛑 Run these commands one at a time

# login to your Azure subscription
az login

# verify the correct subscription
# use az account set -s <sub> to change the sub if required
# you must be the owner of the subscription
# tenant ID should be 72f988bf-86f1-41af-91ab-2d7cd011db47 
az account show -o table

```

### Verify the security group

```bash

# <<<<<<<<<<<<<<<<<<<<<<<<< TODO: design review >>>>>>>>>>>>>>>>>>>>>>>>> 

# Do we need to setup security group to ensure all team members have access to cluster?
# For instance: "asb-ngsa-preprod". For testing I will continue using "asb-hack"


# set your security group name
export ASB_CLUSTER_ADMIN_GROUP=asb-hack

# verify you are a member of the security group
# if you are not a member, please request via Teams chat
az ad group member list -g $ASB_CLUSTER_ADMIN_GROUP  --query [].mailNickname -o table

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
# export ASB_DEPLOYMENT_NAME=[starts with a-z, [a-z,0-9], max length 18]

export ASB_DEPLOYMENT_NAME=ngsacentralasbtest
export ASB_DNS_NAME=ngsa-pre-central-asb-test
export ASB_RG_NAME=ngsa-pre-central-asb-test

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
export ASB_ORG_APP_ID_NAME="BUNewName01"

```

### Create git branch

> Do not PR a `cluster branch` into main
>
> The cluster branch name must be the same as the Team name

```bash
# <<<<<<<<<<<<<<<<<<<<<<<<< TODO: design review >>>>>>>>>>>>>>>>>>>>>>>>> 
# We not need to create new branch since it is required in order to deploy flux.
# I am assuming we want to continue using flux ? 

# create a branch for your cluster
# Do not change the branch name from $ASB_DEPLOYMENT_NAME
git checkout -b $ASB_DEPLOYMENT_NAME
git push -u origin $ASB_DEPLOYMENT_NAME

```

### Choose your deployment region

```bash

🛑 Only choose one pair from the below block

### choose the closest pair - not all regions support ASB
export ASB_LOCATION=centralus
export ASB_GEO_LOCATION=eastus2

```

### Save your work in-progress

```bash

# <<<<<<<<<<<<<<<<<<<<<<<<< TODO: design review >>>>>>>>>>>>>>>>>>>>>>>>> 
# We only need to install kubectl and kubelogin if we enable Codespaces

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

# <<<<<<<<<<<<<<<<<<<<<<<<< TODO: design review >>>>>>>>>>>>>>>>>>>>>>>>> 
# Enable Codespaces, only available for public repos at this time

🛑 # These secrets are for DNS 'aks-sb.com' , we need to update them if we use a different DNS e.g. cse.ms
# set env vars, these should be set into Codespaces enviroment 


# <<<<<<<<<<<<<<<<<<<<<<<<< TODO: design review >>>>>>>>>>>>>>>>>>>>>>>>>
# Note: the stored APP_GW_CERT kv value is not the same as the one stored in Codespaces 

# export APP_GW_CERT=$(az keyvault secret show --subscription bartr-wcnp --vault-name rdc-certs -n aks-sb --query value -o tsv | tr -d '\n')
export INGRESS_CERT=$(az keyvault secret show --subscription bartr-wcnp --vault-name rdc-certs -n aks-sb-crt --query value -o tsv | base64 | tr -d '\n')
export INGRESS_KEY=$(az keyvault secret show --subscription bartr-wcnp --vault-name rdc-certs -n aks-sb-key --query value -o tsv | base64 | tr -d '\n')

# check certs
if [ -z $APP_GW_CERT ]; then echo "App Gateway cert not set correctly"; fi
if [ -z $INGRESS_CERT ]; then echo "Ingress cert not set correctly"; fi
if [ -z $INGRESS_KEY ]; then echo "Ingress key not set correctly"; fi

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
export ASB_GIT_PATH=gitops

🛑 If you have Git configured to use SSH instead of HTTPS.
The command "git remote get-url origin" returns the SSH url which it will cause the flux deployment to fail.
Solution: Manually set the variable "ASB_GIT_REPO" to use with HTTPS url instead


# <<<<<<<<<<<<<<<<<<<<<<<<< TODO: design review >>>>>>>>>>>>>>>>>>>>>>>>>
# What is going to be our pre-prod domain name,  it is "cse.ms" ??
# For this Spike just using 'aks-sb.com'

# set default domain name
export ASB_DNS_ZONE=aks-sb.com  

export ASB_DOMAIN=${ASB_DNS_NAME}.${ASB_DNS_ZONE}

# resource group names
export ASB_RG_CORE=rg-${ASB_RG_NAME}
export ASB_RG_SHARED_HUB_SPOKE=rg-${ASB_RG_NAME}-shared

# export AAD env vars
export ASB_TENANT_ID=$(az account show --query tenantId -o tsv)

# save env vars
./saveenv.sh -y


```

#### Create Resource Groups

```bash

# create the resource groups
az group create -n $ASB_RG_CORE -l $ASB_LOCATION
az group create -n $ASB_RG_SHARED_HUB_SPOKE -l $ASB_LOCATION


```

#### Setup Network

```bash
# Create your spoke deployment file 
cp networking/spoke-BU0001A0008.json networking/spoke-$ASB_ORG_APP_ID_NAME.json

# this section takes 15-20 minutes to complete

# create hub network
az deployment group create -g $ASB_RG_SHARED_HUB_SPOKE -f networking/hub-default.json -p location=${ASB_LOCATION} --query name
export ASB_VNET_HUB_ID=$(az deployment group show -g $ASB_RG_SHARED_HUB_SPOKE -n hub-default --query properties.outputs.hubVnetId.value -o tsv)

# create spoke network
az deployment group create -g $ASB_RG_SHARED_HUB_SPOKE -f networking/spoke-$ASB_ORG_APP_ID_NAME.json -p location=${ASB_LOCATION} orgAppId=${ASB_ORG_APP_ID_NAME} hubVnetResourceId="${ASB_VNET_HUB_ID}" --query name
export ASB_NODEPOOLS_SUBNET_ID=$(az deployment group show -g $ASB_RG_SHARED_HUB_SPOKE -n spoke-$ASB_ORG_APP_ID_NAME --query properties.outputs.nodepoolSubnetResourceIds.value -o tsv)

# create Region A hub network
az deployment group create -g $ASB_RG_SHARED_HUB_SPOKE -f networking/hub-regionA.json -p location=${ASB_LOCATION} nodepoolSubnetResourceIds="['${ASB_NODEPOOLS_SUBNET_ID}']" --query name
export ASB_SPOKE_VNET_ID=$(az deployment group show -g $ASB_RG_SHARED_HUB_SPOKE -n spoke-$ASB_ORG_APP_ID_NAME --query properties.outputs.clusterVnetResourceId.value -o tsv)

./saveenv.sh -y

```

#### Setup AKS

```bash

### this section takes 15-20 minutes

# create AKS
az deployment group create -g $ASB_RG_CORE \
  -f cluster-stamp.json \
  -n cluster-${ASB_DEPLOYMENT_NAME} \
  -p location=${ASB_LOCATION} \
     geoRedundancyLocation=${ASB_GEO_LOCATION} \
     orgAppId=${ASB_ORG_APP_ID_NAME} \
     nodepoolsRGName=${ASB_RG_NAME} \
     asbDnsName=${ASB_DNS_NAME} \
     asbDomain=${ASB_DOMAIN} \
     asbDnsZone=${ASB_DNS_ZONE} \
     targetVnetResourceId=${ASB_SPOKE_VNET_ID} \
     clusterAdminAadGroupObjectId=${ASB_CLUSTER_ADMIN_ID} \
     k8sControlPlaneAuthorizationTenantId=${ASB_TENANT_ID} \
     appGatewayListenerCertificate=${APP_GW_CERT} \
     aksIngressControllerCertificate="$(echo $INGRESS_CERT | base64 -d)" \
     aksIngressControllerKey="$(echo $INGRESS_KEY | base64 -d)" \
     --query name

```

#### Set AKS env vars

```bash
# set public ip address resource name
export ASB_PIP_NAME='pip-'$ASB_ORG_APP_ID_NAME'-00'

# get the name of the deployment key vault
export ASB_KV_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME} --query properties.outputs.keyVaultName.value -o tsv)

# get cluster name
export ASB_AKS_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME} --query properties.outputs.aksClusterName.value -o tsv)

# Get the public IP of our App gateway
export ASB_AKS_PIP=$(az network public-ip show -g $ASB_RG_SHARED_HUB_SPOKE --name $ASB_PIP_NAME --query ipAddress -o tsv)

# Get the AKS Ingress Controller Managed Identity details.
export ASB_TRAEFIK_RESOURCE_ID=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME} --query properties.outputs.aksIngressControllerPodManagedIdentityResourceId.value -o tsv)
export ASB_TRAEFIK_CLIENT_ID=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME} --query properties.outputs.aksIngressControllerPodManagedIdentityClientId.value -o tsv)
export ASB_POD_MI_ID=$(az identity show -n podmi-ingress-controller -g $ASB_RG_CORE --query principalId -o tsv)

# config traefik
export ASB_INGRESS_CERT_NAME=appgw-ingress-internal-aks-ingress-tls
export ASB_INGRESS_KEY_NAME=appgw-ingress-internal-aks-ingress-key

./saveenv.sh -y

```

### Create setup files

```bash

# traefik config
rm -f gitops/ingress/02-traefik-config.yaml
cat templates/traefik-config.yaml | envsubst > gitops/ingress/02-traefik-config.yaml

# app ingress
rm -f gitops/ngsa/ngsa-ingress.yaml
cat templates/ngsa-ingress.yaml | envsubst > gitops/ngsa/ngsa-ingress.yaml

# GitOps (flux)
rm -f flux.yaml
cat templates/flux.yaml | envsubst  > flux.yaml

```


### Push to GitHub
> The setup process creates 4 new files
>
> GitOps will not work unless these files are merged into your branch

```bash

# check deltas - there should be 4 new files
git status

# push to your branch
git add flux.yaml
git add gitops/ingress/02-traefik-config.yaml
git add gitops/ngsa/ngsa-ingress.yaml
git add networking/spoke-$ASB_ORG_APP_ID_NAME.json

git commit -m "added cluster config"
git push

```

### Create a DNS A record

```bash
# <<<<<<<<<<<<<<<<<<<<<<<<< TODO: design review >>>>>>>>>>>>>>>>>>>>>>>>>
# how are we planning to create the dns record?
# manully, gitops ? 
# Question , do we want to move this back to gitops or keep it as manual step ? is it ok to keep it as separate step?
# Look at this script and only execute the required commands to create the dns record in the correct DNS and subscription
# https://github.com/retaildevcrews/asb-spark/blob/main/.github/workflows/create-dns-record.sh


# <<<<<<<<<<<<<<<<<<<<<<<<< TODO: design review >>>>>>>>>>>>>>>>>>>>>>>>>
# What is going to be resource group of DNS Zone for deployment,  it is "cse.ms" ??
# We are using 'dns-rg' for triplets
# For this Spike just using 'TLD'

# resource group of DNS Zone for deployment

DNS_ZONE_RG=TLD 

# create the dns record
az network dns record-set a add-record -g $DNS_ZONE_RG -z $ASB_DNS_ZONE -n $ASB_DNS_NAME -a $ASB_AKS_PIP --query fqdn

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
kubectl apply -f flux.yaml

# 🛑 check the pods until everything is running
kubectl get pods -n flux-cd -l app.kubernetes.io/name=flux

# check flux logs
kubectl logs -n flux-cd -l app.kubernetes.io/name=flux

```

### Validate Ingress

> ASB uses `Traefik` for ingress

```bash

# wait for traefik pods to start
### this can take 2-3 minutes
kubectl get pods -n ingress

## Verify with curl
### this can take 1-2 minutes
### if you get a 502 error retry until you get 200

# test https
curl https://${ASB_DOMAIN}/memory/version

### Congratulations! You have GitOps setup on ASB!

```

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
kubectl delete ns ingress
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
# export ASB_RG_HUB=rg-${ASB_RG_NAME}
# export ASB_RG_SPOKE=rg-${ASB_RG_NAME}
export ASB_RG_SHARED_HUB_SPOKE=rg-${ASB_RG_NAME}-shared

export ASB_AKS_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME} --query properties.outputs.aksClusterName.value -o tsv)
export ASB_KEYVAULT_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME} --query properties.outputs.keyVaultName.value -o tsv)
export ASB_LA_HUB=$(az monitor log-analytics workspace list -g $ASB_RG_SHARED_HUB_SPOKE --query [0].name -o tsv)

# delete and purge the key vault
az keyvault delete -n $ASB_KEYVAULT_NAME
az keyvault purge -n $ASB_KEYVAULT_NAME

# hard delete Log Analytics
az monitor log-analytics workspace delete -y --force true -g $ASB_RG_CORE -n la-${ASB_AKS_NAME}
az monitor log-analytics workspace delete -y --force true -g $ASB_RG_SHARED_HUB_SPOKE -n $ASB_LA_HUB

# delete the resource groups
az group delete -y --no-wait -g $ASB_RG_CORE
az group delete -y --no-wait -g $ASB_RG_SHARED_HUB_SPOKE
# az group delete -y --no-wait -g $ASB_RG_SHARED_HUB_SPOKE

# delete from .kube/config
kubectl config delete-context $ASB_DEPLOYMENT_NAME

# group deletion can take 10 minutes to complete
az group list -o table | grep $ASB_DEPLOYMENT_NAME

### sometimes the spokes group has to be deleted twice
az group delete -y --no-wait -g $ASB_RG_SHARED_HUB_SPOKE

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
