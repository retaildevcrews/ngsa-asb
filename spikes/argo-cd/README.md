# GitOps with ArgoCD Spike

This document is intended for learning and development purposes and will guide a user through a spike on setting up a Continuous Deployment (CD) workflow using ArgoCD, which is a GitOps continuous delivery tool. GitOps is a software development methodology that uses Git as a single source of truth for declarative infrastructure and application configuration. ArgoCD simplifies the process of deploying applications by automating the management of Kubernetes resources using a GitOps approach. As part of the setup, we will be using Azure Kubernetes Service (AKS) to host the Kubernetes cluster. By following this document, users will learn how to set up an AKS cluster, install and configure ArgoCD, and deploy a sample application using GitOps principles. For further reference, users can consult the official [ArgoCD documentation](https://argoproj.github.io/argo-cd/).

## Prerequisites

Before starting, you will need the following:

- An Azure account
- Azure CLI [download](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- ArgoCD CLI [download](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
- kubectl [download](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

- You will need at least one AKS cluster, or more if you are planning to set up a multi-cluster deployment.

## Step 0: Create an AKS cluster **Skip if you already have a cluster** 

1. Open a terminal or command prompt and log in to your Azure account with the following command:

```bash
az login
```

2. Create a resource group for your AKS cluster with the following command, replacing <resource-group> with a name for your resource group and <location> with the Azure region where you want your resources to be located:

```bash
az group create --name <resource-group> --location <location>
```

3. Create an AKS cluster with the following command, replacing <cluster-name> with a name for your cluster, and <node-count> with the number of nodes you want in your cluster:

```bash
az aks create --resource-group <resource-group> --name <cluster-name> --node-count <node-count> --enable-addons monitoring --generate-ssh-keys
```

4. Connect to the AKS cluster:

```bash
az aks get-credentials --resource-group <resource-group> --name <cluster-name>
```

5. Verify that you can connect to the AKS cluster:

```bash

kubectl get nodes

```


## Step 1:  Install ArgoCD

1. Install ArgoCD by running the following commands:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

2. Verify that ArgoCD is running:

```bash
kubectl get pods -n argocd
```

3. Access the ArgoCD web UI by running the following command, and then open the URL in a web browser:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

4. Log in to the ArgoCD web UI with the following credentials:
- Username: admin
- Password: Retrieve the ArgoCD password by running one of the following command:

```bash
# kubectl
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# argocd cli
argocd admin initial-password -n argocd
```

