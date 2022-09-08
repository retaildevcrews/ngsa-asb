# Deploy NGSA using YAML and FluxCD

## Create NGSA deployment files

```bash

# create the ngsa namespace
kubectl create ns ngsa

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
flux reconcile kustomization -n ngsa ngsa

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
