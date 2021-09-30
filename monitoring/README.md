# Adding Azure Monitor source in Grafana

The following instructions allow adding Azure Monitor data source to create custom Grafana dashboards in an existing AKS cluster.

## Prerequisites

- An AKS-Secure Baseline cluster
- Permission to add a service principal to a resource group in Azure Portal/CLI
- Permission to assign service principal/app registration to Reader role.

## Setup

### Import Grafana into ACR

- Variables `ASB_RG_CORE` and `ASB_DEPLOYMENT_NAME` are from the cluster deployment script [Sort name](../README.md#set-deployment-short-name) and 
[Variables](../README.md#set-variables-for-deployment)

```bash
# import Grafana into ACR
export ASB_ACR_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}  --query properties.outputs.containerRegistryName.value -o tsv)

az acr import --source docker.io/io/grafana/grafana:7.3.0 -n $ASB_ACR_NAME

# create grafana deployment file
mkdir $ASB_GIT_PATH/monitoring
cat templates/grafana.yaml | envsubst  > $ASB_GIT_PATH/monitoring/grafana.yaml

```

### Deploy Grafana

- Flux will pick up the latest changes. Use the command below to force flux to sync.
  
  ```bash
  fluxctl sync
  ```

- Check that it worked by running the following: kubectl port-forward service/grafana 3000:3000 -n monitoring
- Navigate to localhost:3000 in your browser. You should see a Grafana login page.
- Use admin for both the username and password to login.

### Adding required permissions/secrets from Azure Portal

- A new app registration/service principal can be created for Grafana access.
- Create a new client/secret for the service principal (Portal)

## Add a secret to the service principal

Select a descriptive name when creating the service principal `<your-service-principal-name>` e.g  `grafana-reader`

- Goto Azure Active Directory --> App Registration
- Click New Registration and enter `<your-service-principal-name>`
  - Select option "Accounts in this organizational directory only (Microsoft only - Single tenant)"
  - Click Register, this will open up the App registrations settings screen.
- From App registrations settings --> Certificates and Secrets
  - Create a new Client secret, this will be use later to configure Azure Monitor in grafana

### Assign a role to the application (Portal)

- Go to resource group `<your-resource-group>` --> Access Control (IAM) --> Role Assignments
- Look for and add the service principal created `<your-service-principal-name>` as "Reader"

## Add Azure Monitor Source in Grafana

Get access to Grafana dashboard

Goto a browser to access grafana and perform the following steps:

- Goto Configuration --> Data Sources
- "Add data source" --> Select "Azure Monitor"
- Inside "Azure Monitor" Source
  - Under Azure Monitor Details
    - Put in Directory (Tenant) ID, Application (Client) ID (service principal `<your-service-principal-name>` ID) and Client Secret from [Add a secret to the service principal](#add-a-secret-to-the-service-principal)
    - Click on "Load Subscription" --> After loading, select proper subscription from drop-down
  - Under Application Insights
    - Put in "API Key" and "Application ID" from [this step](#add-api-key-to-app-insights)
  - Click "Save & Test"
- Click on "Explore" from Grafana side bar
- Try out different metrics and services

## Import Grafana dashboard JSON file into Grafana

- Navigate to localhost:3000 in your browser to get Grafana login page
- Go to `Dashboards` > `Manage` page from left menu
- Click `Import`
- Upload dashboard file [ngsa-dev-model.json](../monitoring/dashboards/ngsa-dev-model.json)
