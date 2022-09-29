# NGSA AKS Secure Baseline

* [Introduction](#introduction)
* [Setup Infrastructure](#setup-infrastructure)
* [Deploying NGSA Applications](#deploying-ngsa-applications)
* [Deploying LodeRunner Applications](#deploying-loderunner-applications)
* [Deploy Fluent Bit](#deploy-fluent-bit)
* [Deploy Grafana and Prometheus](#deploy-grafana-and-prometheus)
* [Leveraging Subdomains for App Endpoints](#leveraging-subdomains-for-app-endpoints)
* [Deploy WASM sidecar filter](#deploy-wasm-sidecar-filter)
* [Deploying Multiple Clusters Using Existing Network](#deploying-multiple-clusters-using-existing-network)
* [Resetting the Cluster](#resetting-the-cluster)
* [Delete Azure Resources](#delete-azure-resources)

## Introduction

NGSA AKS Secure Base line uses the Patterns and Practices AKS Secure Baseline reference implementation located [here](https://github.com/mspnp/aks-secure-baseline).

* Please refer to the PnP repo as the `upstream repo`
* Please use Codespaces

## Setup Infrastructure

```bash
./scripts/deployASB.sh

# If you would like to restart deployment you can delete current deployment file
# RUN: rm .current-deployment

```

## Deploying NGSA Applications

### 🛑 Prerequisite - [Setup Cosmos DB in secure baseline](./docs/cosmos.md)

### Create managed identity for NGSA app

```bash

# Create managed identity for ngsa-app
export ASB_NGSA_MI_NAME="${ASB_DEPLOYMENT_NAME}-ngsa-id"

export ASB_NGSA_MI_RESOURCE_ID=$(az identity create -g $ASB_RG_CORE -n $ASB_NGSA_MI_NAME --query "id" -o tsv)

# save env vars
./saveenv.sh -y

```

### AAD pod identity setup for ngsa-app

```bash

# allow cluster to manage app identity for aad pod identity
export ASB_AKS_IDENTITY_ID=$(az aks show -g $ASB_RG_CORE -n $ASB_AKS_NAME --query "identityProfile.kubeletidentity.objectId" -o tsv)

az role assignment create --role "Managed Identity Operator" --assignee $ASB_AKS_IDENTITY_ID --scope $ASB_NGSA_MI_RESOURCE_ID

# give app identity read access to secrets in keyvault
export ASB_NGSA_MI_PRINCIPAL_ID=$(az identity show -n $ASB_NGSA_MI_NAME -g $ASB_RG_CORE --query "principalId" -o tsv)

az keyvault set-policy -n $ASB_KV_NAME --object-id $ASB_NGSA_MI_PRINCIPAL_ID --secret-permissions get

# save env vars
./saveenv.sh -y
```

NGSA Application can be deployed into the cluster using two different approaches:

* [Deploy using yaml with FluxCD](./docs/deployNgsaYaml.md)

* [Deploy using AutoGitops with FluxCD](https://github.com/bartr/autogitops)

  * AutoGitOps is reccomended for a full CI/CD integration. For this approach the application repository must be autogitops enabled.

## Deploying LodeRunner Applications

### 🛑 Prerequisite - [Setup Cosmos DB in secure baseline.](./docs/cosmos.md)

### Create managed identity for LodeRunner app

```bash

# Create managed identity for loderunner-app
export ASB_LR_MI_NAME="${ASB_DEPLOYMENT_NAME}-loderunner-id"

export ASB_LR_MI_RESOURCE_ID=$(az identity create -g $ASB_RG_CORE -n $ASB_LR_MI_NAME --query "id" -o tsv)

# save env vars
./saveenv.sh -y

```

### AAD pod identity setup for loderunner-app

```bash

# allow cluster to manage app identity for aad pod identity
export ASB_AKS_IDENTITY_ID=$(az aks show -g $ASB_RG_CORE -n $ASB_AKS_NAME --query "identityProfile.kubeletidentity.objectId" -o tsv)

az role assignment create --role "Managed Identity Operator" --assignee $ASB_AKS_IDENTITY_ID --scope $ASB_LR_MI_RESOURCE_ID

# give app identity read access to secrets in keyvault
export ASB_LR_MI_PRINCIPAL_ID=$(az identity show -n $ASB_LR_MI_NAME -g $ASB_RG_CORE --query "principalId" -o tsv)

az keyvault set-policy -n $ASB_KV_NAME --object-id $ASB_LR_MI_PRINCIPAL_ID --secret-permissions get

# Add to KeyVault
az keyvault secret set -o table --vault-name $ASB_KV_NAME --name "CosmosLRDatabase" --value "LodeRunnerDB"
az keyvault secret set -o table --vault-name $ASB_KV_NAME --name "CosmosLRCollection" --value "LodeRunner"

# save env vars
./saveenv.sh -y
```

LodeRunner Application can be deployed into the cluster using two different approaches:

* [Deploy using yaml with FluxCD](./docs/deployLodeRunnerYaml.md)

* [Deploy using AutoGitops with FluxCD](https://github.com/bartr/autogitops)

  * AutoGitOps is reccomended for a full CI/CD integration. For this approach the application repository must be autogitops enabled.

## Deploy Fluent Bit

```bash
# Import image into ACR
az acr import --source docker.io/fluent/fluent-bit:1.9.5 -n $ASB_ACR_NAME

# Create namespace
kubectl create ns fluentbit

# Create secrets to authenticate with log analytics
kubectl create secret generic fluentbit-secrets --from-literal=WorkspaceId=$(az monitor log-analytics workspace show -g $ASB_RG_CORE -n $ASB_LA_NAME --query customerId -o tsv)   --from-literal=SharedKey=$(az monitor log-analytics workspace get-shared-keys -g $ASB_RG_CORE -n $ASB_LA_NAME --query primarySharedKey -o tsv) -n fluentbit

# Load required yaml

mkdir $ASB_GIT_PATH/fluentbit

cp templates/fluentbit/01-namespace.yaml $ASB_GIT_PATH/fluentbit/01-namespace.yaml

cp templates/fluentbit/02-config.yaml $ASB_GIT_PATH/fluentbit/02-config.yaml

cat templates/fluentbit/03-config-log.yaml | envsubst > $ASB_GIT_PATH/fluentbit/03-config-log.yaml

cp templates/fluentbit/04-role.yaml  $ASB_GIT_PATH/fluentbit/04-role.yaml

cat templates/fluentbit/05-daemonset.yaml | envsubst > $ASB_GIT_PATH/fluentbit/05-daemonset.yaml

git add $ASB_GIT_PATH/fluentbit

git commit -m "added fluentbit"

git push

# Sync Flux
flux reconcile kustomization -n fluentbit fluentbit
# Note: `fluxctl` CLI has a default timeout of 60s, if the above `fluxctl sync` command times out it means `fluxcd` is still working on it

```

🛑 Known issue: Fluentbit is sending random duplicate logs to Log Analytics
As mitigation action we recommend filtering out duplicates when performing queries against ingesss_CL and ngsa_CL logs by utilizing the 'distinct' operator.

```bash
ngsa_CL
| where TimeGenerated > ago (10m)
| distinct Date_t, TimeGenerated, _timestamp_d, TraceID_g, SpanID_s, Zone_s, path_s

ingress_CL
| where TimeGenerated > ago (5m)
| where isnotnull(start_time_t)
| distinct  start_time_t, TimeGenerated, _timestamp_d, x_b3_spanid_s, x_b3_traceid_g, request_authority_s, Zone_s, path_s

```

## Deploy Grafana and Prometheus

Please see Instructions to deploy Grafana and Prometheus [here](./monitoring/README.md)

## Leveraging Subdomains for App Endpoints

### Motivation

It's common to expose various public facing applications through different paths on the same endpoint (eg: `my-asb.cse.ms/cosmos`, `my-asb.cse.ms/grafana` and etc). A notable problem with this approach is that within the App Gateway, we can only configure a single health probe for all apps in the cluster. This can bring down the entire endpoint if the health probe fails, when only a single app was affected.

A better approach would be to use a unique subdomain for each app instance. The subdomain format is `[app].[region]-[env].cse.ms`, where the order is in decreasing specificity. Ideally, grafana in the central dev region can be accessed as `grafana.central-dev.cse.ms`. However, adding a second level subdomain means that we will need to purchase an additional cert. We currently own the `*.cse.ms` wildcard cert but we cannot use the same cert for a a secondary level such as `*.central-dev.cse.ms` ([more info](https://serverfault.com/questions/104160/wildcard-ssl-certificate-for-second-level-subdomain/658109#658109)). Therefore, for our ASB installation, we will use a workaround by modifying the subdomain format to `[app]-[region]-[env].cse.ms`, which still maintains the same specificity order and each app can still have its own unique endpoint.

### Create a subdomain endpoint

```bash

# app DNS name, in subdomain format
# format [app]-[region]-[env].cse.ms
export ASB_APP_NAME=[application-name] # e.g: ngsa-cosmos, ngsa-java, ngsa-memory, loderunner.
export ASB_APP_DNS_NAME=${ASB_APP_NAME}-${ASB_SPOKE_LOCATION}-${ASB_ENV}
export ASB_APP_DNS_FULL_NAME=${ASB_APP_DNS_NAME}.${ASB_DNS_ZONE}
export ASB_APP_HEALTH_ENDPOINT="/healthz"

# create record for public facing DNS
az network dns record-set a add-record -g $ASB_DNS_ZONE_RG -z $ASB_DNS_ZONE -n $ASB_APP_DNS_NAME -a $ASB_AKS_PIP --query fqdn

# create record for private DNS zone
export ASB_AKS_PRIVATE_IP="$ASB_SPOKE_IP_PREFIX".4.4
az network private-dns record-set a add-record -g $ASB_RG_CORE -z $ASB_DNS_ZONE -n $ASB_APP_DNS_NAME -a $ASB_AKS_PRIVATE_IP --query fqdn

```

#### Create app gateway resources

🛑 NOTE: In case of encounter an error when creating app gateway resources refer to [Disable WAF config](./docs/disableWAFconfig.md)

```bash
# backend pool, HTTPS listener (443), health probe, http setting and routing rule
export ASB_APP_GW_NAME="apw-$ASB_AKS_NAME"

az network application-gateway address-pool create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n $ASB_APP_DNS_FULL_NAME --servers $ASB_APP_DNS_FULL_NAME

az network application-gateway http-listener create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "listener-$ASB_APP_DNS_NAME" --frontend-port "apw-frontend-ports" --ssl-cert "$ASB_APP_GW_NAME-ssl-certificate" \
  --host-name $ASB_APP_DNS_FULL_NAME

az network application-gateway probe create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "probe-$ASB_APP_DNS_NAME" --protocol https --path $ASB_APP_HEALTH_ENDPOINT \
  --host-name-from-http-settings true --interval 30 --timeout 30 --threshold 3 \
  --match-status-codes "200-399"

az network application-gateway http-settings create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "$ASB_APP_DNS_NAME-httpsettings" --port 443 --protocol Https --cookie-based-affinity Disabled --connection-draining-timeout 0 \
  --timeout 20 --host-name-from-backend-pool true --enable-probe --probe "probe-$ASB_APP_DNS_NAME"

export MAX_RULE_PRIORITY=$(az network application-gateway rule list -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME --query "max([].priority)")

export ABS_HTTPSETTINGS_RULE_PRIORITY=$(($MAX_RULE_PRIORITY+1))

# Verify that the new prority is correct.
echo $ABS_HTTPSETTINGS_RULE_PRIORITY

az network application-gateway rule create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "$ASB_APP_DNS_NAME-routing-rule" --address-pool $ASB_APP_DNS_FULL_NAME \
  --http-settings "$ASB_APP_DNS_NAME-httpsettings" --http-listener "listener-$ASB_APP_DNS_NAME" --priority $ABS_HTTPSETTINGS_RULE_PRIORITY 

🛑 Note: If the command 'az network application-gateway rule create' fails due to priority value already been used, please refer to Azure portal in order to identify a priority that does not exist yet.

# set http redirection
# create listener for HTTP (80), HTTPS redirect config and HTTPS redirect routing rule
az network application-gateway http-listener create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "http-listener-$ASB_APP_DNS_NAME" --frontend-port "apw-frontend-ports-http" --host-name $ASB_APP_DNS_FULL_NAME

az network application-gateway redirect-config create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "https-redirect-config-$ASB_APP_DNS_NAME" -t "Permanent" --include-path true \
  --include-query-string true --target-listener "listener-$ASB_APP_DNS_NAME"

export MAX_RULE_PRIORITY=$(az network application-gateway rule list -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME --query "max([].priority)")

export ABS_HTTPS_REDIRECT_RULE_PRIORITY=$(($MAX_RULE_PRIORITY+1))

# Verify that the new prority is correct.
echo $ABS_HTTPS_REDIRECT_RULE_PRIORITY

az network application-gateway rule create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "https-redirect-$ASB_APP_DNS_NAME-routing-rule" --http-listener "http-listener-$ASB_APP_DNS_NAME" \
  --redirect-config "https-redirect-config-$ASB_APP_DNS_NAME" --priority $ABS_HTTPS_REDIRECT_RULE_PRIORITY

```

## Deploy WASM sidecar filter

The following instructions will help you get started to deploy a sidecar filter for ngsa-cosmos

*Optional* The WASM Filter source code can be referenced [here](https://github.com/retaildevcrews/istio)

```bash
# Set target app
export WASM_TARGET_APP=ngsa-cosmos

# Istio-injection is enabled at the ngsa-cosmos deployment through the sidecar.istio.io/inject=true annotation

# Copy yaml files to cluster deployment directory
mkdir $ASB_GIT_PATH/burst
cp templates/burst/burst-metrics-service.yaml $ASB_GIT_PATH/burst
cat templates/burst/remote-filter.yaml | envsubst > $ASB_GIT_PATH/burst/remote-filter-$WASM_TARGET_APP.yaml

# Commit changes
git add $ASB_GIT_PATH/burst
git commit -m "added burst for ${WASM_TARGET_APP}"
git push

# Sync Flux
flux reconcile kustomization -n burstservice burst
# Note: `fluxctl` CLI has a default timeout of 60s, if the above `fluxctl sync` command times out it means `fluxcd` is still working on it

# Note: It may be required to re-create the ngsa-cosmos and istio operator pods for changes to take effect
kubectl delete pod -n istio-operator -l name=istio-operator
kubectl delete pod -n ngsa -l app=ngsa-cosmos

# Test changes (you should now see the x-load-feedback headers)
http https://ngsa-cosmos-$ASB_DOMAIN_SUFFIX/healthz

```

## Deploying Multiple Clusters Using Existing Network

Please see Instructions to deploy Multiple Clusters Using Existing Network [here](./docs/deployAdditionalCluster.md)

## Resetting the cluster

> Reset the cluster to a known state
>
> This is normally signifcantly faster for inner-loop development than recreating the cluster

```bash
# delete the namespaces
# this can take 4-5 minutes
### order matters as the deletes will hang and flux could try to re-deploy
kubectl delete ns flux-system
kubectl delete ns ngsa
kubectl delete ns istio-system
kubectl delete ns istio-operator
kubectl delete ns monitoring
kubectl delete ns cluster-baseline-settings
kubectl delete ns fluentbit

# check the namespaces
kubectl get ns

# start over at Deploy Flux
```

## Adding resource locks to resource groups

Set resource locks on resources groups to prevent accidental deletions. This can be done in the Azure portal or with az cli.

Review the [documentation on the side effects](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/lock-resources?tabs=json#considerations-before-applying-your-locks) of the different types of resource locks. Our use case will be the `CanNotDelete` type to prevent deletions.

```bash

# view resource groups in the current subscription
az group list -o table

# view only the names, query the name field
az group list --query "[].name" -o tsv

# view existing resource locks
az lock list -o table

# create a lock to prevent deletions in the desired resource groups
LOCK_RESOURCE_GROUP="<resource group name>"
az lock create \
  --lock-type CanNotDelete \
  --name "$LOCK_RESOURCE_GROUP" \
  --resource-group "$LOCK_RESOURCE_GROUP"

```

## Delete Azure Resources

> Do not just delete the resource groups. Double check for existing resource locks and disable as needed.

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

export ASB_AKS_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.aksClusterName.value -o tsv)
export ASB_KEYVAULT_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION} --query properties.outputs.keyVaultName.value -o tsv)
export ASB_LA_HUB=$(az monitor log-analytics workspace list -g $ASB_RG_HUB --query [0].name -o tsv)

# delete and purge the key vault
az keyvault delete -n $ASB_KEYVAULT_NAME
az keyvault purge -n $ASB_KEYVAULT_NAME

# hard delete Log Analytics
az monitor log-analytics workspace delete -y --force true -g $ASB_RG_CORE -n $ASB_LA_NAME
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
az deployment group delete -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}
```

### Run Checkov scan

- Navigate to `Codespaces main menu` (top left icon with three horizontal lines)
- Click on `Terminal` menu item, then `Run Task`
- From tasks menu locate `Run Checkov Scan` and click on it
- Task terminal will show up executing substasks and indicating when scan completed
- Scan results file `checkov_scan_results` will be created at root level, and automatically will get open by VSCode
- Review the file and evaluate failed checks. For instance:

```bash
  kubernetes scan results:

  Passed checks: 860, Failed checks: 146, Skipped checks: 0
  ...
  ...

  dockerfile scan results:

  Passed checks: 22, Failed checks: 4, Skipped checks: 0

  ...
  ...

```
