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