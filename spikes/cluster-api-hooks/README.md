# TODO: rough notes

TODO: diagram extension setup and hooks flow

TODO:

- briefly tried getting local clusters working with k3d with no luck
- try again and see if it is relatively easy to get it working with k3d setup vs simply installing kind
- if sticking with kind, make note of choice and reason for moving away from default k3d setup
  - short version, cluster api had kind instructions

```bash

# setup

docker run \
    -d --restart=always \
    -p "127.0.0.1:5001:5000" \
    --name "kind-registry" \
    registry:2

# TODO: install kind. <https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries>
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.14.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# create local kind management cluster
kind create cluster --config spikes/cluster-api-hooks/kind-cluster.yaml

docker network connect "kind" "kind-registry"

kubectl apply -f spikes/cluster-api-hooks/local-registry-configmap.yaml

# capi init

export EXP_AKS=true
export EXP_MACHINE_POOL=true
export CLUSTER_TOPOLOGY=true
export EXP_RUNTIME_SDK=true

# initialize local kind management cluster
clusterctl init --infrastructure docker

# build extension

docker build spikes/cluster-api-hooks/sample-extension \
  -f spikes/cluster-api-hooks/sample-extension/Dockerfile \
  -t localhost:5001/capi-sample-extension

docker push localhost:5001/capi-sample-extension

# deploy extension

kubectl apply -f spikes/cluster-api-hooks/sample-extension/deploy

kubectl wait pod --for=condition=Ready -l app=sample-extension --timeout=60s

# register the extention with cluster api
kubectl apply -f spikes/cluster-api-hooks/sample-extension/extension-config.yaml

# rapid testing with of extension with local kind clusters
# make changes to extension, deploy and test locally
# then create AKS clusters for further testing
# saves time since creating, updating, and deleting an AKS cluster can take minutes

export BASE_CAPI_CONFIG_DIR="spikes/cluster-api-hooks/capi-configs"

mkdir -p $BASE_CAPI_CONFIG_DIR

export DOCKER_CLUSTER_YAML_PATH="${BASE_CAPI_CONFIG_DIR}/capi-quickstart-docker.yaml"

clusterctl generate cluster capi-quickstart-docker \
  --kubernetes-version v1.24.0 \
  --control-plane-machine-count=1 \
  --worker-machine-count=1 \
  --infrastructure=docker \
  --flavor development \
  > "$DOCKER_CLUSTER_YAML_PATH"

# create local kind workload cluster
kubectl apply -f "$DOCKER_CLUSTER_YAML_PATH"

# view the cluster in cluster api
kubectl get clusters

# view the kind cluster
kind get clusters

# view the logs of the extension to see the lifecycle hooks in action
kubectl logs -l app=sample-extension

# delete the cluster
kubectl delete cluster capi-quickstart-docker

# view the updated logs again after cluster has been deleted
kubectl logs -l app=sample-extension

```

inner-loop dev

Use local kind clusters to test code changes locally before testing on cloud clusters

- update extension go code
- run local build command
- push to local registry
- restart extention deployment a.k.a delete pod
  - `kubectl delete pod -l app=sample-extension`
- create, update, or delete a local kind cluster
- observe behavior of updated hooks
- repeat process

TODO: get AKS working with ClusterClass CRD

```bash

# TODO: initial setup for creating AKS cluster
# - duplicate notes here so spike is standalone (leaning towards this route)
# - or point relevant section in other spike docs
# - or other

clusterctl init --infrastructure azure

export AZURE_CONTROL_PLANE_MACHINE_TYPE="Standard_A2_v2"
export AZURE_NODE_MACHINE_TYPE="Standard_A2_v2"

export AKS_CLUSTER_YAML_PATH="${BASE_CAPI_CONFIG_DIR}/capi-quickstart-aks.yaml"

# TODO: need a template using ClusterClass for lifecycle hooks to work

clusterctl generate cluster capi-quickstart-aks \
  --kubernetes-version v1.24.0 \
  --control-plane-machine-count=1 \
  --worker-machine-count=1 \
  --infrastructure=azure \
  --flavor=aks \
  > "$AKS_CLUSTER_YAML_PATH"

kubectl apply -f "$AKS_CLUSTER_YAML_PATH"

# view the cluster in cluster api
kubectl get clusters

```

sample extension config location
<https://github.com/kubernetes-sigs/cluster-api/blob/main/docs/proposals/20220221-runtime-SDK.md#registering-runtime-extensions>