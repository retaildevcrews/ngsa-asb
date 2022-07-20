#!/bin/sh

# install k3d
wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | TAG=v5.4.4 bash

# install clusterctl
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.1.5/clusterctl-linux-amd64 -o clusterctl
chmod +x ./clusterctl
sudo mv ./clusterctl /usr/local/bin/clusterctl
