# Lab: Single App of Apps Per Cluster

## Introduction

This lab will walk you through the setup of a multi-cluster ArgoCD example of installing cluster add-ons using an app of apps pattern.  The goal of this lab is to demonstrate:

- how ArgoCD can be used to deploy a set of applications to multiple clusters
- how context values can be passed down to the app of apps
- how values for a helm chart can be overwritten using an external values file

During the lab you will:

1. Set up 4 k3d clusters - management cluster, and 3 workload clusters
2. Set up ArgoCD
3. Deploy an application set that deploys the add-ons to the worker clusters

## Prerequisites

1. Kubectl - Installation instructions here: <https://kubernetes.io/docs/tasks/tools/>
2. Argo CLI - Installation instructions here: <https://argo-cd.readthedocs.io/en/stable/cli_installation/>
3. Docker - Installation instruction here: <https://docs.docker.com/engine/install/>
   > **Note**
   > You can validate you have docker running by running the following command
   > docker --version
4. k3d-
   > **Note**
   > You can validate you have docker running by running the following command
   > k3d --version

    ``` bash
    #Install latest version of k3d
    wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | sudo bash
    ```

5. Argo CLI - Install Argo CLI by following instructions found here: <https://argo-cd.readthedocs.io/en/stable/cli_installation/>
   > **Note**
   > When running certain commanda like cluster add, argocd cli will make calls to cluster using kubeconfig context's server value.  It will also use this within the argo management cluster to add the destination cluster.  Because the management cluster has no knowledge of the destination server's control plane at the default server in the context which is 0.0.0.0, it will not be able to reach the destination servers control plane.  To get around this we will use the host.k3d.internal feature to provide a dns alias to the server.  To do this we will need to edit your systems hosts file by adding the following entry:  

   ``` bash
   # Added to enable running argocd cli  on local k3d instances
   0.0.0.0         host.k3d.internal

## Steps

1. Ensure you are executing this lab from the spikes/cluster-add-ons/single-app-of-apps-per-cluster directory

2. Create k3d Clusters

    ``` bash
    k3d cluster create workload-cluster-1 --kubeconfig-update-default=false;
    k3d cluster create workload-cluster-2 --kubeconfig-update-default=false;
    k3d cluster create workload-cluster-3 --kubeconfig-update-default=false;
    k3d cluster create argomgmt --kubeconfig-update-default=false;
    k3d kubeconfig merge --all -o config-argo;
    export KUBECONFIG=config-argo
    kubectl config use-context k3d-argomgmt 
    ```

3. Validate current kubectl context is set to k3d-argomgmt

    ``` bash
    kubectl config current-context
    ```

4. Install ArgoCD

    ``` bash
    kubectl create namespace argocd;
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml;
    # Wait until all pods are showing 1/1 in ready state
    kubectl wait pods -n argocd --all --for condition=ready
    ```

5. Expose API Server External to Cluster (run this command in a new zsh terminal so port forwarding remains running)

    ``` bash
    # Forward port to access UI outside of cluster
    export KUBECONFIG=config-argo;
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```

    After this step is complete go back to original terminal to run the rest of the commands

6. Access UI

    1. Get initial password

        ``` bash
        # Get the initial password for installation - make note
        argocd admin initial-password -n argocd --config
        ````

    2. You can now access UI by going to: <https://localhost:8080>
    3. Log in using User: admin and Password: from step 6.1
    4. Navigate to <https://localhost:8080/user-info>
    5. Click Update Password Button and change to your password of choice
    6. You will then be logged out, log back in using credentials above

7. Add clusters in Argo

    ``` bash
    #Connect to api server 
    argocd login localhost:8080 --username admin --password <same_password_used_in_ui>
    argocd cluster add k3d-workload-cluster-1 --name workload-cluster-1 --insecure;
    argocd cluster add k3d-workload-cluster-2 --name workload-cluster-2 --insecure;
    argocd cluster add k3d-workload-cluster-3 --name workload-cluster-3 --insecure
    ```

8. Create applicationset to deploy workloads

    ``` bash
    kubectl apply -f addon_generator.yaml --insecure-skip-tls-verify
    ```

9. Navigate to UI by going to: <https://localhost:8080> to see applications being deployed

   > **Note**
   > At this point all applications are being deployed at once - using this pattern where each addon is its own app of apps does not give the ability to express dependencies between add-ons

10. Clean Up

    ``` bash
    k3d cluster delete workload-cluster-1 ;
    k3d cluster delete workload-cluster-2 ;
    k3d cluster delete workload-cluster-3 ;
    k3d cluster delete argomgmt;
    unset KUBECONFIG;
    rm config-argo
    ```
