# Cluster API Lifecycle Hook spike

This spike covers a sample development workflow of a Cluster API [lifecycle hook runtime extensions](https://cluster-api.sigs.k8s.io/tasks/experimental-features/runtime-sdk/implement-lifecycle-hooks.html) using kind clusters. The [test extention](https://github.com/kubernetes-sigs/cluster-api/tree/main/test/extension) from Cluster API is used as the foundation of this spike.

## Diagrams

TODO: add info about requests that will be made <https://editor.swagger.io/?url=https://cluster-api.sigs.k8s.io/tasks/experimental-features/runtime-sdk/runtime-sdk-openapi.yaml>

Deployment
TODO: diagram extension setup and hooks flow

Development loop
TODO: diagram extension setup and hooks flow

## Management cluster setup

Setup a local Cluster API management cluster using Kind.

```bash

# start a container registry for kind
docker run \
    -d --restart=always \
    -p "127.0.0.1:5001:5000" \
    --name "kind-registry" \
    registry:2

# install kind. <https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries>
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.14.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# create local kind management cluster
kind create cluster --config spikes/cluster-api-hooks/kind-cluster.yaml

# connect the registry to the same network as the cluster
docker network connect "kind" "kind-registry"

# expose the registry to the cluster
kubectl apply -f spikes/cluster-api-hooks/local-registry-configmap.yaml

# initialize cluster api
export EXP_MACHINE_POOL=true
export CLUSTER_TOPOLOGY=true
export EXP_RUNTIME_SDK=true

clusterctl init --infrastructure docker

```

## Build extension

Build the sample extention and deploy it to the local container registry

```bash

# build and tag
docker build spikes/cluster-api-hooks/sample-extension \
  -f spikes/cluster-api-hooks/sample-extension/Dockerfile \
  -t localhost:5001/capi-sample-extension

# push image
docker push localhost:5001/capi-sample-extension

```

## Initial deployment

```bash

# deploy the extention for the first time
kubectl apply -f spikes/cluster-api-hooks/sample-extension/deploy

# wait for deployment to be ready
kubectl wait pod --for=condition=Ready -l app=sample-extension --timeout=60s

# register the extention with cluster api
kubectl apply -f spikes/cluster-api-hooks/sample-extension/extension-config.yaml

```

## Test extension

With Cluster API and the sample extention ready, create another cluster to test the extention. For a quick development loop, Kind clusters can be created, updated, and deleted quickly to test the lifecycle hook extension before testing on a non-local cluster. This allows for rapid development by removing the time to deploy cloud infrastructure.

```bash

# create directory for spike cluster configs
export BASE_CAPI_CONFIG_DIR="spikes/cluster-api-hooks/capi-configs"

mkdir -p $BASE_CAPI_CONFIG_DIR

export DOCKER_CLUSTER_YAML_PATH="${BASE_CAPI_CONFIG_DIR}/capi-quickstart-docker.yaml"

# generate configuration files for a Kind workload cluster
clusterctl generate cluster capi-quickstart-docker \
  --kubernetes-version v1.24.0 \
  --control-plane-machine-count=1 \
  --worker-machine-count=1 \
  --infrastructure=docker \
  --flavor development \
  > "$DOCKER_CLUSTER_YAML_PATH"

# apply the workload cluster config file to the management cluster
kubectl apply -f "$DOCKER_CLUSTER_YAML_PATH"

```

## Verify results

View the behavior of the different components involved in the flow.

```bash

# view the workload cluster resource in the cluster api management cluster
kubectl get clusters

# view the newly created cluster directly with kind
kind get clusters

# view the logs of the extension to see the lifecycle hooks in action
# there will be log messages prefixed with "SPIKE".
kubectl logs -l app=sample-extension

# delete the workload cluster
kubectl delete cluster capi-quickstart-docker

# view the updated logs again after the workload cluster has been deleted
kubectl logs -l app=sample-extension

```

## Further development

The developer can now repease the process below to test and verify changes locally.

1. update extension code
1. build and tag container image
1. push to local registry
1. restart extention deployment a.k.a delete pod
    - `kubectl delete pod -l app=sample-extension`
1. create, update, or delete a workload cluster's configuration
1. observe behavior of updated hooks
1. repeat process
