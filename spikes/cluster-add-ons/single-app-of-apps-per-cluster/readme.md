# Lab: Single App of Apps Per Cluster

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

## Steps

1. Install Argo CLI by following instructions found here: <https://argo-cd.readthedocs.io/en/stable/cli_installation/>

2. Create k3d Clusters and network

    ``` bash
    # Create Docker Network for k3d
    docker network create k3d
    k3d cluster create workload-cluster-1 --network k3d;
    k3d cluster create workload-cluster-2 --network k3d;
    k3d cluster create workload-cluster-3 --network k3d;
    k3d cluster create argomgmt --network k3d
    ```

3. Validate current kubectl context is set to k3d-argomgmt

    ``` bashku
    kubectl config current-context
    ```

4. Install ArgoCD

    ``` bash
    kubectl create namespace argocd;
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml ;
    # Wait until all pods are showing 1/1 in ready state
    kubectl wait pods -n argocd --all --for condition=ready
    ```

5. Expose API Server External to Cluster (run this command in a new zsh terminal so port forwarding remains running)

    ``` bash
    # Forward port to access UI outside of cluster
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```

    After this step is complete go back to original terminal to run the rest of the commands

6. Access UI

    1. Get initial password

        ``` bash
        # Get the initial password for installation - make note
        argocd admin initial-password -n argocd
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
    argocd cluster add k3d-workload-cluster-1 --name workload-cluster-1 --insecure
    argocd cluster add k3d-workload-cluster-2 --name workload-cluster-2 --insecure
    argocd cluster add k3d-workload-cluster-3 --name workload-cluster-3 --insecure
    ```

8. Create applicationset to deploy workloads

    ``` bash
    kubectl apply -f /addon_generator.yaml
    ```

9. Delete Clusters

    ``` bash
    k3d cluster delete workload-cluster-1 ;
    k3d cluster delete workload-cluster-2 ;
    k3d cluster delete workload-cluster-3 ;
    k3d cluster delete argomgmt;
    docker network rm k3d
    ```
