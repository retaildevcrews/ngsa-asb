# Argo Workflows Spike

Argo Workflows is a robust Kubernetes-native orchestration framework designed to facilitate the creation, management, and execution of complex, containerized workflows in a seamless manner. Argo Workflows offers various features such as parameterized workflows, conditional logic, parallelism, and support for multiple artifact repositories, making it an ideal choice for a wide range of use cases, including data processing and continuous integration and deployment (CI/CD).

This spike tutorial will focus on the fundamentals of Argo Workflows, covering its key components, the Workflow CRD, and the workflow-controller. We will also discuss how to configure Argo Workflows using ConfigMaps. Additionally, the tutorial will showcase a practical example of deploying two Helm charts in each step, focusing on two applications: ngsa-memory and loderunner.

## Prerequisites

Before we dive into the installation process, ensure that you have the following prerequisites in place:

- Kubernetes Cluster: A running Kubernetes cluster (version 1.18 or later) with administrative access.
- Helm [download](https://helm.sh/docs/intro/install/)
- kubectl [download](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)

## Installation

To install Argo Workflows, follow the steps outlined below:

```bash
# Add the official Argo Helm repository to your Helm client:
helm repo add argo https://argoproj.github.io/argo-helm

# Update your Helm client's local repository cache:
helm repo update

# Create a dedicated namespace for Argo Workflows
kubectl create namespace argo

# Install Argo Workflows using the Helm chart from the Argo repository:
helm install argo-workflows argo/argo-workflows --namespace argo --set installCRDs=true

# Verify the installation. You should see the workflow-controller and argo-server pods running.
kubectl get pods -n argo

```

## Exploring Argo Workflows and Deploying Applications

In this section we will explore the fundamentals of Argo Workflows and learn how to deploy applications using Helm charts. We will focus on two applications: ngsa-memory and loderunner.

### Understanding Argo Workflows

Argo Workflows is built around the concept of a Workflow, which is a sequence of tasks that run on Kubernetes using containerized steps. Each step in a Workflow is executed as a Kubernetes Pod, which allows for parallelism and flexible error handling. The Workflow is defined using a YAML file, which includes the definition of the steps and their dependencies.

Let's break down the key components of an Argo Workflow:

- **Workflow CRD:** A Custom Resource Definition (CRD) that extends the Kubernetes API to support Workflow objects.
- **Workflow Controller:** A Kubernetes controller that watches for Workflow objects and manages their execution.
- **Argo Server:** A server that provides the Argo UI and API, enabling users to visualize and manage Workflows.

In Kubernetes, a ServiceAccount is used to provide an identity for processes that run in a Pod. When deploying resources with Argo Workflows, it is important to grant the necessary permissions to the Workflow to create, update, and delete resources such as Deployments, Pods, Services, and Namespaces. To achieve this, a ServiceAccount with the appropriate ClusterRole and ClusterRoleBinding is required. The ClusterRole defines the permissions needed for the Workflow, while the ClusterRoleBinding associates the ServiceAccount with the ClusterRole, allowing the Argo Workflow to perform the desired actions within the cluster.

To create the required ServiceAccount, ClusterRole, and ClusterRoleBinding, run the following commands:

```bash
kubectl apply -f manifests/helm-deployment-sa.yaml
kubectl apply -f manifests/helm-deployment-clusterrole.yaml
kubectl apply -f manifests/helm-deployment-clusterrolebinding.yaml
```

### Creating an Argo Workflow for Deploying Applications

Now, let's install an Argo Workflow that deploys the ngsa-memory and loderunner applications using Helm charts. To do this, we have provided a YAML file under `manifests/argo-workflow.yaml` This Workflow defines a single step that deploys both the ngsa-memory and loderunner applications. Each application deployment is executed using the deploy-helm-chart template, which runs the Helm command with the appropriate parameters.

To submit the Workflow, run the following command.

```bash
# This command will submit the Workflow to the Argo server and watch its progress.
argo submit argo-workflow.yaml --watch
```

You can monitor the Workflow execution using the Argo UI or the argo get command. To access the Argo UI, follow these steps:

- Run `kubectl port-forward svc/argo-workflows-server -n argo 2746:2746`
- Open your browser and navigate to http://localhost:2746 `argo get <workflow-name>`
