# Deploy NGSA using YAML and FluxCD

## Create managed identity for app

```bash

# Create managed identity for ngsa-app
export ASB_NGSA_MI_NAME="${ASB_DEPLOYMENT_NAME}-ngsa-id"

export ASB_NGSA_MI_RESOURCE_ID=$(az identity create -g $ASB_RG_CORE -n $ASB_NGSA_MI_NAME --query "id" -o tsv)

# save env vars
./saveenv.sh -y

```

## AAD pod identity setup for app

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

## Create NGSA deployment files

```bash

export ASB_NGSA_MI_CLIENT_ID=$(az identity show -n $ASB_NGSA_MI_NAME -g $ASB_RG_CORE --query "clientId" -o tsv)

mkdir -p $ASB_GIT_PATH/ngsa
cat templates/ngsa/ngsa-cosmos.yaml | envsubst > $ASB_GIT_PATH/ngsa/ngsa-cosmos.yaml
cat templates/ngsa/ngsa-memory.yaml | envsubst > $ASB_GIT_PATH/ngsa/ngsa-memory.yaml
cat templates/ngsa/ngsa-java.yaml | envsubst > $ASB_GIT_PATH/ngsa/ngsa-java.yaml
cat templates/ngsa/ngsa-pod-identity.yaml | envsubst > $ASB_GIT_PATH/ngsa/ngsa-pod-identity.yaml

# save env vars
./saveenv.sh -y

```

### Push to GitHub

```bash

# check deltas - there should be 4 new files
git status

# push to your branch
git add $ASB_GIT_PATH/ngsa/ngsa-cosmos.yaml
git add $ASB_GIT_PATH/ngsa/ngsa-memory.yaml
git add $ASB_GIT_PATH/ngsa/ngsa-java.yaml
git add $ASB_GIT_PATH/ngsa/ngsa-pod-identity.yaml
git commit -m "added ngsa config"
git push

```

Flux will pick up the latest changes. Use the command below to force flux to sync.

```bash

# force flux to sync changes
fluxctl sync --k8s-fwd-ns flux-cd

```

### Configure App Subdomain Endpoints

By default, ASB will setup the subdomain endpoint for the NGSA memory application. You will need to manually setup the endpoints for the `ngsa-cosmos` and `ngsa-java` apps. Follow the steps in the [subdomain setup guide](../README.md#create-a-subdomain-endpoint) for each application endpoint to setup.

### Validate

```bash

# wait for ngsa-cosmos pods to start
### this can take 8-10 minutes as the cluster sets up pod identity, and secrets via the csi driver
kubectl get pods -n ngsa
kubectl get pods -n istio-system

http https://ngsa-cosmos-${ASB_DOMAIN_SUFFIX}/version
http https://ngsa-memory-${ASB_DOMAIN_SUFFIX}/version
http https://ngsa-java-${ASB_DOMAIN_SUFFIX}/version
```

### Deploy Loderunner

```bash
mkdir -p $ASB_GIT_PATH/loderunner 

cat templates/loderunner.yaml | envsubst > $ASB_GIT_PATH/loderunner/loderunner.yaml

git add $ASB_GIT_PATH/loderunner/loderunner.yaml
git commit -m "added loderunner"
git push

# Force flux to sync changes
fluxctl sync --k8s-fwd-ns flux-cd

# Check loderunner pod loderunner until is running

kubectl get pods -n loderunner

# Check loderunner logs and make sure 200 status code entries do exist for both ngsa-cosmos and ngsa-memory

kubectl logs deployment/loderunner -n loderunner

```
