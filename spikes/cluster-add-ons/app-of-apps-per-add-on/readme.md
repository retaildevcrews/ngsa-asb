# Lab: App of Apps Per Add-on

## Steps

1. Install Argo CLI by following instructions found here: <https://argo-cd.readthedocs.io/en/stable/cli_installation/>

2. Create Kind Clusters

    ``` bash
    kind create cluster --name argomgmt
    kind create cluster --name workload-cluster-1
    kind create cluster --name workload-cluster-2
    kind create cluster --name workload-cluster-3
    ```

3. Set context to management cluster

    ``` bash
    kubectl cluster-info --context argomgmt
    ```

4. Install ArgoCD

    ``` bash
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```

5. Expose API Server External to Cluster

    ``` bash
    # Forward port to access UI outside of cluster
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```

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

7. Create applicationset to deploy workloads

    ``` bash
    kubectl apply -f /addon_generator.yaml
    ```

8. Delete Clusters

    ``` bash
    kind delete cluster --name workload-cluster-1
    kind delete cluster --name workload-cluster-2
    kind delete cluster --name workload-cluster-3
    kind delete cluster --name argomgmt
    ```
