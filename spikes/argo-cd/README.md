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
kubectl apply -f spikes/argo-cd/manifests/argo-ngsa-app.yaml -n argocd
```

- Rollbacks cannot be performed against an application with automated sync enabled

## Step 3:  Target Multiple Clusters

You can use ArgoCD to deploy and manage applications across different clusters without having to install ArgoCD in each cluster manually.

To achieve this, ArgoCD uses Kubernetes contexts. A context is a set of access parameters for a Kubernetes cluster. These parameters include the cluster's API server URL, the credentials needed to access the cluster, and the default namespace to use for deployments.

When you configure ArgoCD to target multiple clusters, you create a Kubernetes context for each cluster and configure ArgoCD to use those contexts. ArgoCD will then use the context to access the API server of each target cluster and deploy applications.

### Step 3.1: Create A Second Cluster

Create a second cluster using the same steps outlined in step 0 and get the credentials into your kube config
```bash

# Create an AKS cluster with the following command, replacing <cluster-name> with a name for your cluster, and <node-count> with the number of nodes you want in your cluster:
az aks create --resource-group <resource-group> --name <cluster-name> --location <location> --generate-ssh-keys

# Merge AKS cluster into local kube config:
az aks get-credentials --resource-group <resource-group> --name <cluster-name>

# Set config cluster to initial cluster where ArgoCD is installed:
kubectl config set-cluster <cluster-name>
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

### Step 3.2: Choosing The Right Application-Set Controller Generator

The ApplicationSet controller in Argo CD is a component that enhances application automation and aims to enhance the management of multiple clusters and tenants. Argo CD Applications can be generated from various sources such as Git or Argo CD's pre-defined cluster list. You will find a sample under the manifests folder.

Choosing the right application-set generator is dependent on what type of cluster management is needed.

If clusters are predefined with little to no changes to clusters, manually adding or removing clusters is adequate, and the deployment/addition of applications can be separated to different clusters/environments, use a list generator. Applications can be separated to different clusters by putting their yaml deployment in the appropriate cluster folder.

Update the cluster information in the manifest directed below and run the command to deploy an example.

```bash

kubectl apply -f spikes/argo-cd/manifests/list-generator/application-set-list.yaml -n argocd

```

If clusters are more dynamic where the creation/modification are happening more often, using a git generator may be better. A git generator is the most flexible and allows the ability for administrators to restrict some fields from being controlled by developers in the application spec. A folder can be targeted in the git repo to where if a config.json file is checked-in/modified, a cluster will be created/removed appropriately.

Update the cluster information in the config.json in the directory below and run the command to deploy an example.

```bash

kubectl apply -f spikes/argo-cd/manifests/git-generator/application-set-git.yaml -n argocd

```

If a more hands-off approach to targeting cluster deployment is needed, a cluster generator can be used. Deployments can target all or specific clusters by using a "match label" to select local or remote clusters.

```bash

kubectl apply -f spikes/argo-cd/manifests/cluster-generator/application-set-cluster.yaml -n argocd

```

- Beware: Cluster name must be lowercase or it will unable to find the cluster.

## Step 4: Customizing Deployment Order With Sync-Waves

### Step 4.1: Sync-Wave

Sync-waves allow resources to be deployed in a specific order. By adding the annotation to the deployment yaml, Argo CD will control how the application rolls out. All deployment manifests are 0 by default, and can be set to a negative number as well.

Argo CD won't apply the next manifest until the previous reports "healthy".

```bash

metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"

```

### Step 4.2: Hooks

Hooks control the deployment even further. Hooks can be defined by the 4 stages...

- PreSync - Runs before the sync operation and can be a database migration or backup.
- Sync - Runs after PreSync successfully ran and will run with normal manifests.
- PostSync - Runs after Sync successfully ran and can be an email notification
- SyncFail - Runs if the Sync operation failed and can be used to send fail notifications or other operations

In addition to sync operations, hook deletions state can be specified.

- HookSucceeded - Resource will be deleted after it has succeeded.
- HookFailed - Resource will be deleted if it has failed.
- BeforeHookCreation - Resource will be deleted before a new one is created during a new sync.

BeforeHookCreation is the default deletion state for hooks if not specified.

```bash

metadata:
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded

```

### Step 4.3 Progressive Syncs

During this time of writing (03/27/2023), this feature is in alpha and can be subjected to change or removal in future releases.

Progressive syncs are similar to sync-waves to where deployments can only continue when the current resource is "healthy". However, these work at the application group level.

- RollingSync will force all generated Applications to have autosync disabled

```bash

# Edit config map to enable feature
kubectl edit configmap argocd-cmd-params-cm -n argocd

# Add this to configmap and save
data:
  applicationsetcontroller.enable.progressive.syncs: "true"

# Get the pod name for the application set controller
kubectl get pods -n argocd

# Delete pod so it can restart with the config map changes
kubectl delete pod <argocd-applicationset-controller-name> -n argocd

```
