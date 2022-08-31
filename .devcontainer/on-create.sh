#!/bin/sh

# install k3d
wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | TAG=v5.4.4 bash

# install clusterctl
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.1.5/clusterctl-linux-amd64 -o clusterctl
chmod +x ./clusterctl
sudo mv ./clusterctl /usr/local/bin/clusterctl

# install latest flux in ~/.local/bin
curl -s https://fluxcd.io/install.sh |  bash -s - ~/.local/bin
# install flux completions for bash
echo '. <(flux completion bash)' >> ~/.bashrc
# install flux completions for zsh
echo '. <(flux completion zsh)' >> ~/.zshrc

# create local registry
docker network create k3d
k3d registry create registry.localhost --port 5000
docker network connect k3d k3d-registry.localhost
