## Deploy NGSA using YAML and FluxCD

### Create ngsa-cosmos deployment file

```bash
export ASB_NGSA_MI_CLIENT_ID=$(az identity show -n $ASB_NGSA_MI_NAME -g $ASB_RG_CORE --query "clientId" -o tsv)

cat templates/ngsa-cosmos.yaml | envsubst > $ASB_GIT_PATH/ngsa/ngsa-cosmos.yaml
cat templates/ngsa-memory.yaml | envsubst > $ASB_GIT_PATH/ngsa/ngsa-memory.yaml
cat templates/ngsa-java.yaml | envsubst > $ASB_GIT_PATH/ngsa/ngsa-java.yaml
cat templates/ngsa-pod-identity.yaml | envsubst > $ASB_GIT_PATH/ngsa/ngsa-pod-identity.yaml

# save env vars
./saveenv.sh -y

```

### Push to GitHub

```bash

# check deltas - there should be 1 new file
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

curl https://${ASB_DOMAIN}/cosmos/version
curl https://${ASB_DOMAIN}/memory/version
curl https://${ASB_DOMAIN}/java/version
```

### Import Loderunner into ACR

```bash

# import l8r into ACR

export ASB_ACR_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}  --query properties.outputs.containerRegistryName.value -o tsv)

az acr import --source ghcr.io/retaildevcrews/ngsa-lr:beta -n $ASB_ACR_NAME

rm -f  load-test.yaml
cat templates/load-test.yaml | envsubst > load-test.yaml

```

### Deploy Loderunner

```bash
kubectl apply -f load-test.yaml

# Check loderunner pod l8r-load-1 until is running

kubectl get pods -n ngsa

# Check loderunner logs and make sure 200 status code entries do exist for both ngsa-cosmos and ngsa-memory

kubectl logs l8r-load-1 -n ngsa

```