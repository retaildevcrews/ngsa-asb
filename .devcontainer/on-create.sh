#!/bin/sh

echo "on-create started" >> $HOME/status

# Change shell to zsh for vscode
sudo chsh --shell /bin/zsh vscode

# Install k3d > 5.0.1
k3d --version | grep -Eo '^k3d version v5...[1-9]$' > /dev/null 2>&1
if [ $? -ne 0 ]; then
    # Means we don't have proper k3d version
    # Install v5.4.6
    echo "Installing k3d v5.4.6"
    wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | TAG=v5.4.6 sudo bash
fi

# Create Docker Network for k3d
docker network create k3d

# Create local container registry
k3d registry create registry.localhost --port 5000

# Connect to local registry
docker network connect k3d k3d-registry.localhost

# install clusterctl (Cluster API)
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.1.5/clusterctl-linux-amd64 -o clusterctl
chmod +x ./clusterctl
sudo mv ./clusterctl /usr/local/bin/clusterctl

# install kubelogin
wget https://github.com/Azure/kubelogin/releases/download/v0.0.20/kubelogin-linux-amd64.zip
unzip -p kubelogin-linux-amd64.zip bin/linux_amd64/kubelogin > kubelogin
chmod +x kubelogin
sudo mv kubelogin /usr/local/bin/kubelogin
rm kubelogin-linux-amd64.zip

# install latest flux in ~/.local/bin
curl -s https://fluxcd.io/install.sh |  bash -s - ~/.local/bin
# install flux completions for bash
echo '. <(flux completion bash)' >> ~/.bashrc
# install flux completions for zsh
echo '. <(flux completion zsh)' >> ~/.zshrc

echo "on-create completed" > $HOME/status
