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



### Create ngsa deployment files

export ASB_NGSA_MI_CLIENT_ID=$(az identity show -n $ASB_NGSA_MI_NAME -g $ASB_RG_CORE --query "clientId" -o tsv)

mkdir -p $ASB_GIT_PATH/ngsa
cat templates/ngsa-cosmos.yaml | envsubst > $ASB_GIT_PATH/ngsa/ngsa-cosmos.yaml
cat templates/ngsa-memory.yaml | envsubst > $ASB_GIT_PATH/ngsa/ngsa-memory.yaml
cat templates/ngsa-java.yaml | envsubst > $ASB_GIT_PATH/ngsa/ngsa-java.yaml
cat templates/ngsa-pod-identity.yaml | envsubst > $ASB_GIT_PATH/ngsa/ngsa-pod-identity.yaml

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
git commit -m "added ngsa-cosmos config"
git push

```

Flux will pick up the latest changes. Use the command below to force flux to sync.

```bash

# force flux to sync changes
fluxctl sync --k8s-fwd-ns flux-cd

```

### Validate

```bash

# wait for ngsa-cosmos pods to start
### this can take 8-10 minutes as the cluster sets up pod identity, and secrets via the csi driver
kubectl get pods -n ngsa
kubectl get pods -n istio-system

http https://${ASB_DOMAIN}/cosmos/version
http https://${ASB_DOMAIN}/memory/version
http https://${ASB_DOMAIN}/java/version
```

### Deploy Loderunner

```bash

cp templates/load-test.yaml $ASB_GIT_PATH/ngsa/load-test.yaml

git add $ASB_GIT_PATH/ngsa/load-test.yaml
git commit -m "added ngsa-lr "
git push

# force flux to sync changes
fluxctl sync --k8s-fwd-ns flux-cd

# Check loderunner pod l8r-load-1 until is running

kubectl get pods -n ngsa

# Check loderunner logs and make sure 200 status code entries do exist for both ngsa-cosmos and ngsa-memory

kubectl logs l8r-load-1 -n ngsa

```
