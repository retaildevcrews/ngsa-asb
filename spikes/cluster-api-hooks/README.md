# TODO: rough notes

```bash

docker run \
    -d --restart=always \
    -p "127.0.0.1:5001:5000" \
    --name "kind-registry" \
    registry:2

kind create cluster --config spikes/cluster-api-hooks/kind-cluster.yaml

docker network connect "kind" "kind-registry"

kubectl apply -f spikes/cluster-api-hooks/local-registry-configmap.yaml

# TODO: rest of initial cluster setup

export EXP_AKS=true
export EXP_MACHINE_POOL=true
export CLUSTER_TOPOLOGY=true
export EXP_RUNTIME_SDK=true

clusterctl init --infrastructure azure,docker

# TODO: post initialization env var and other setup

DOCKER_BUILDKIT=1 docker build spikes/cluster-api-hooks/extension \
  -f spikes/cluster-api-hooks/extension/Dockerfile \
  -t localhost:5001/capi-extension
docker push localhost:5001/capi-extension

kubectl apply -f spikes/cluster-api-hooks/extension/deploy
kubectl wait pod --for=condition=Ready -l app=sample-extension --timeout=60s
kubectl apply -f spikes/cluster-api-hooks/extension/extension-config.yaml

```

TODO: rapid testing with of extension with local clusters

```bash

clusterctl generate cluster capi-quickstart-docker \
  --kubernetes-version v1.24.0 \
  --control-plane-machine-count=1 \
  --worker-machine-count=1 \
  --flavor development \
  --infrastructure=docker \
  > "$DOCKER_CLUSTER_YAML_PATH"

kubectl apply -f "$DOCKER_CLUSTER_YAML_PATH"

```
