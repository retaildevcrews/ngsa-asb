# GitOps with ArgoCD Spike

This document is intended for learning and development purposes and will guide a user through a spike on setting up a Continuous Deployment (CD) workflow using ArgoCD, which is a GitOps continuous delivery tool. GitOps is a software development methodology that uses Git as a single source of truth for declarative infrastructure and application configuration. ArgoCD simplifies the process of deploying applications by automating the management of Kubernetes resources using a GitOps approach. As part of the setup, we will be using Azure Kubernetes Service (AKS) to host the Kubernetes cluster. By following this document, users will learn how to set up an AKS cluster, install and configure ArgoCD, and deploy a sample application using GitOps principles. For further reference, users can consult the official [ArgoCD documentation](https://argo-cd.readthedocs.io/en/stable/).

## Prerequisites

Before starting, you will need the following:

- An Azure account
- Azure CLI [download](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- ArgoCD CLI [download](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
- kubectl [download](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

- You will need at least one AKS cluster, or more if you are planning to set up a multi-cluster deployment.

## Step 0: Create an ArgoCD management cluster with AKS

To create a new management cluster in AKS, run the following commands. Otherwise, if you already have an existing AKS cluster, you can skip this step and proceed to connecting to the existing AKS cluster.

```bash
# Connecting to Azure with specific tenant (e.g. microsoft.onmicrosoft.com)
az login --tenant '{Tenant Id}'

# Change the active subscription using the subscription name
az account set --subscription "{Subscription Id or Name}"

# Create a resource group for your AKS cluster with the following command, replacing <resource-group> with a name for your resource group and <location> with the Azure region where you want your resources to be located:
az group create --name <resource-group> --location <location>

# Create an AKS cluster with the following command, replacing <cluster-name> with a name for your cluster, and <node-count> with the number of nodes you want in your cluster:
az aks create --resource-group <resource-group> --name <cluster-name> --location <location> --generate-ssh-keys

# Connect to the AKS cluster:
az aks get-credentials --resource-group <resource-group> --name <cluster-name>

#Verify that you can connect to the AKS cluster:
kubectl get nodes

```

## Step 1:  Install ArgoCD

You can install ArgoCD on your Kubernetes cluster by running the following commands in your terminal or command prompt. These commands will download and install ArgoCD on your cluster, allowing you to use it for GitOps-based continuous delivery of your applications

```bash
kubectl create namespace argocd
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml -n argocd

# Verify that ArgoCD is running:
kubectl get pods -n argocd

# Access the ArgoCD web UI by running the following command, and then open the URL in a web browser:
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Log in to the ArgoCD web UI with the following credentials:
# - Username: admin
# - Password: Retrieve the ArgoCD password by running one of the following command:

argocd admin initial-password -n argocd

# Alternatively, you can also retrieve the credentials using kubectl.
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Step 2:  Deploy a sample application with GitOps

Now that ArgoCD has been installed on the cluster, you can deploy your application using GitOps in two different ways: via the UI or via YAML declaration.

### UI Setup

Add the Git repository as a new application in the ArgoCD web UI:

- In the ArgoCD web UI, click on the New App button.
- In the Create New Application form, fill in the following fields:
  - Application Name: `ngsa`
  - Project: `default`
  - Sync Policy: `Automatic`
  - Auto-Create Namespace: `Checked`
  - Repository URL: `https://github.com/retaildevcrews/ngsa-asb`
  - Path: `spikes/argo-cd/deploy`
  - Cluster URL: `https://kubernetes.default.svc`
  - Namespace: `ngsa`

Click on the Create button.
Verify that the ngsa application is running by running the following command:

```bash
kubectl get pods -n ngsa
```

### YAML

Alternatively you can declare an argo application deployment using yaml.

```bash
kubectl apply -f spikes/argo-cd/manifests/argo-ngsa-app.yaml
```

## Step 3:  Target Multiple Clusters

You can use ArgoCD to deploy and manage applications across different clusters without having to install ArgoCD in each cluster manually.

To achieve this, ArgoCD uses Kubernetes contexts. A context is a set of access parameters for a Kubernetes cluster. These parameters include the cluster's API server URL, the credentials needed to access the cluster, and the default namespace to use for deployments.

When you configure ArgoCD to target multiple clusters, you create a Kubernetes context for each cluster and configure ArgoCD to use those contexts. ArgoCD will then use the context to access the API server of each target cluster and deploy applications.

### Step 3.1: Create A Second Cluster

Create a second cluster using the same steps outlined in step 0 and get the credentials into your kube config
```bash

# Create an AKS cluster with the following command, replacing <cluster-name> with a name for your cluster, and <node-count> with the number of nodes you want in your cluster:
az aks create --resource-group <resource-group> --name <cluster-name> --location <location> --generate-ssh-keys

# Connect to the AKS cluster:
az aks get-credentials --resource-group <resource-group> --name <cluster-name>
```

```bash

# Login to Argo
argocd login localhost:8080

# List the current contexts associated with the management cluster
argocd cluster list

# Add one or more cluster contexts to argo
argocd cluster add <cluster-context-name>
```

A url will be outputted and that will be the url Argo CD will use to connect to the second cluster.

Now you can return the the UI and manually deploy an application to multiple clusters.

The ApplicationSet controller in Argo CD is a component that enhances application automation and aims to enhance the management of multiple clusters and tenants. Argo CD Applications can be generated from various sources such as Git or Argo CD's pre-defined cluster list. You will find a sample under the manifests folder.

If deploying by yaml...

- Remove the existing argo application deployment as the application-set-sample.yaml will re-deploy the application and there will be a sync issue between the two applications.

- Update the cluster list url in the application-set-sample.yaml.

```bash

kubectl apply -f spikes/argo-cd/manifests/application-set-sample.yaml -n argocd

```

### Step 3.2: Choosing The Right ApplicationSet Controller Generator

If the need is to be able to pick certain applications to deploy to specific clusters, use a list generator.

The folde