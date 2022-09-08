# Deploy LodeRunnner using YAML and FluxCD

## Create LodeRunner deployment files

```bash

# create the loderunner namespace
kubectl create ns loderunner

export ASB_LR_MI_CLIENT_ID=$(az identity show -n $ASB_LR_MI_NAME -g $ASB_RG_CORE --query "clientId" -o tsv)

mkdir -p $ASB_GIT_PATH/loderunner
cat templates/loderunner/loderunner-api.yaml | envsubst > $ASB_GIT_PATH/loderunner/loderunner-api.yaml
cat templates/loderunner/loderunner-clientmode.yaml | envsubst > $ASB_GIT_PATH/loderunner/loderunner-clientmode.yaml
cat templates/loderunner/loderunner-commandmode.yaml | envsubst > $ASB_GIT_PATH/loderunner/loderunner-commandmode.yaml
cat templates/loderunner/loderunner-ui.yaml | envsubst > $ASB_GIT_PATH/loderunner/loderunner-ui.yaml
cat templates/loderunner/loderunner-pod-identity.yaml | envsubst > $ASB_GIT_PATH/loderunner/loderunner-pod-identity.yaml

# save env vars
./saveenv.sh -y

```

### Push to GitHub

```bash

# check deltas - there should be 4 new files
git status

# push to your branch
git add $ASB_GIT_PATH/loderunner/loderunner-api.yaml.yaml
git add $ASB_GIT_PATH/loderunner/loderunner-clientmode.yaml
git add $ASB_GIT_PATH/loderunner/loderunner-commandmode.yaml
git add $ASB_GIT_PATH/loderunner/loderunner-ui.yaml
git add $ASB_GIT_PATH/loderunner/loderunner-pod-identity.yaml
git commit -m "added loderunner apps"
git push

```

Flux will pick up the latest changes. Use the command below to force flux to sync.

```bash

# Force flux to sync changes
flux reconcile kustomization -n loderunner loderunner

# Check loderunner pod loderunner until is running

kubectl get pods -n loderunner

# Check loderunner logs and make sure 200 status code entries do exist for both loderunner-ui and loderunner-api

kubectl logs deployment/loderunner -n loderunner

```

### Configure App Subdomain Endpoints

You will need to manually setup the endpoints for the `loderunner` app. Follow the steps in the [subdomain setup guide](../README.md#create-a-subdomain-endpoint) for each application endpoint to setup.

### Validate

```bash

# wait for loderunner-cosmos pods to start
### this can take 8-10 minutes as the cluster sets up pod identity, and secrets via the csi driver
kubectl get pods -n loderunner
kubectl get pods -n istio-system

http https://loderunner-${ASB_DOMAIN_SUFFIX}
http https://loderunner-${ASB_DOMAIN_SUFFIX}/api

```
