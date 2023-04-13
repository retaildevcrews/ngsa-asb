# Argo Workflows Spike

Argo Workflows is a robust Kubernetes-native orchestration framework designed to facilitate the creation, management, and execution of complex, containerized workflows in a seamless manner. Argo Workflows offers various features such as parameterized workflows, conditional logic, parallelism, and support for multiple artifact repositories, making it an ideal choice for a wide range of use cases, including data processing and continuous integration and deployment (CI/CD).

This spike tutorial will focus on the fundamentals of Argo Workflows, covering its key components, the Workflow CRD, and the workflow-controller. We will also discuss how to configure Argo Workflows using ConfigMaps. Additionally, the tutorial will showcase a practical example of deploying two Helm charts in each step, focusing on two applications: ngsa-memory and loderunner.

## Prerequisites

Before we dive into the installation process, ensure that you have the following prerequisites in place:

- Kubernetes Cluster: A running Kubernetes cluster (version 1.18 or later) with administrative access.
- Helm [download](https://helm.sh/docs/intro/install/)
- kubectl [download](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
- Argo Workflows CLI [download](https://github.com/argoproj/argo-workflows/releases/)

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
kubectl apply -f manifests/serviceaccount.yaml
kubectl apply -f manifests/clusterrole.yaml
kubectl apply -f manifests/clusterrolebinding.yaml
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

### Managing Helm dependencies using Helm Hooks

Helm hooks are a powerful feature within the Helm package manager that allow users to perform custom actions at specific points in a release's lifecycle. These hooks enable greater flexibility and control during the installation, upgrade, rollback, or deletion of a Helm chart. By attaching scripts or Kubernetes resources to predefined hook events, users can automate tasks such as pre-install checks, or post-delete cleanup. This functionality enhances the management of complex applications, ensuring that necessary actions are executed in the correct order and at the appropriate times during the deployment process.

We have defined several Helm hooks within the manifest folder, consisting of a Job and a ConfigMap. The ConfigMap contains a script designed to check for dependencies, specifically focusing on the version of the ngsa-memory app. This dependency check ensures that our Helm chart is compatible with the ngsa-memory app version before proceeding with the installation or upgrade. The Job, which is responsible for executing the dependency check, mounts the ConfigMap within a container. By doing so, it can run the script, verifying that all required dependencies are met before the Helm chart is installed or upgraded. This setup provides an automated and reliable way to ensure compatibility between our application and the ngsa-memory app during deployment.

## Argo Events

Argo Events is a robust workflow orchestration tool designed for Kubernetes, that operates on an event-driven architecture. This tool empowers you to craft custom workflows that react to events from a variety of sources, including webhooks, message queues, or customized event sources.

### Installing Argo Events

```bash
# Add the Helm Repository for Argo Events
helm repo add argo https://argoproj.github.io/argo-helm

# Update the Helm Repository
helm repo update

# Create Argo Events namespace
kubectl create ns argo-events

# Install Argo Events
helm install argo-events argo/argo-events --namespace argo-events

# Verify pods
kubectl get pods -n argo-events

```

### Installing Eventbus and required components

```bash
# The Eventbus is a message broker that provides a central hub for event messages. It allows event sources and sensors to communicate with each other using a publish-subscribe model.  

# Install Eventbus 
kubectl apply -f manifests/events/eventbus.yaml -n argo-events

# The Event Source listens for incoming events and sends them to the Eventbus for processing. In this case, the Event Source is named webhook and listens for incoming events on port 12000. The service section specifies the Kubernetes Service that exposes the Event Source deployment. The webhook section defines the details of the webhook event source. In this case, the webhook listens for incoming webhook events on port 12000 and the /example endpoint using the HTTP POST method. When an event is received, it is sent to the Eventbus for further processing. This allows the webhook event source to trigger Argo Events workflows based on incoming webhook events.

# Create a webhook event source that will send events to our Argo sensor. Event sources in Argo Events are used to receive events from various external systems. This YAML file defines an EventSource that listens for incoming webhook events on port 12000 and the /webhook endpoint.
kubectl apply -f manifests/events/webhook-event-source.yaml -n argo-events

# Install RBAC for sensor and workflow
kubectl apply -f manifests/events/sensor-rbac.yaml -n argo-events
kubectl apply -f manifests/events/workflow-rbac.yaml -n argo-events

# Create a sensor that listens for events from the webhook event source and triggers the "Hello World" workflow. Sensors in Argo Events are used to define event-driven rules and trigger actions based on events.
# This YAML file defines a Sensor that listens for events from the webhook-event-source and triggers the webhook workflow when an event is received.
kubectl apply -f manifests/events/webhook-sensor.yaml -n argo-events

```

### Send an Event to Trigger the Workflow

We'll send a POST request to the webhook event source to trigger the "Hello World" workflow. This will simulate an external event being received by the webhook event source.

```bash

# First, start a port-forwarding session to make the webhook event source accessible from your local machine:
kubectl -n argo-events port-forward $(kubectl -n argo-events get pod -l eventsource-name=webhook -o name) 12000:12000 &

# Send a POST request to the webhook event source using a tool like curl:
curl -d '{"message":"Hello Team!"}' -H "Content-Type: application/json" -X POST http://localhost:12000/example

# Verify that an Argo workflow was triggered.
kubectl -n argo-events get workflows | grep "webhook"
```
