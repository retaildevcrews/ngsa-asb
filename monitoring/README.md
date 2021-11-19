# Setup Monitoring

The following instructions deploy Prometheus and add an Azure Monitor data source to create custom Grafana dashboards in an existing AKS cluster.

## Prerequisites

- An AKS-Secure Baseline cluster
- Permission to add a service principal to a resource group in Azure Portal/CLI
- Permission to assign service principal/app registration to Reader role.

## Setup

### Import Prometheus and Grafana into ACR

- Variables `ASB_RG_CORE` and `ASB_DEPLOYMENT_NAME` are from the cluster deployment script [Sort name](../README.md#set-deployment-short-name) and [Variables](../README.md#set-variables-for-deployment)

```bash

export ASB_ACR_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}  --query properties.outputs.containerRegistryName.value -o tsv)

# import Prometheus into ACR
az acr import --source docker.io/prom/prometheus:v2.30.0 -n $ASB_ACR_NAME

# import jumpbox into ACR. (jumpbox is required by prometheus to be able to mount a volume for persistent data)
az acr import --source ghcr.io/cse-labs/jumpbox -n $ASB_ACR_NAME

# import Grafana into ACR
az acr import --source docker.io/grafana/grafana:7.3.0 -n $ASB_ACR_NAME

```

### Create Deployment Templates

```bash

mkdir $ASB_GIT_PATH/monitoring
# create monitoring namespace deployment file
cat templates/monitoring.yaml | envsubst  > $ASB_GIT_PATH/monitoring/01-namespace.yaml
# create prometheus deployment file
cat templates/prometheus.yaml | envsubst  > $ASB_GIT_PATH/monitoring/02-prometheus.yaml

```

#### Option 1: Prepare Grafana deployment for basic auth

Deploy the standard version of Grafana using basic auth, essentially providing username and password for login.

```bash

# create grafana deployment file
cat templates/grafana.yaml | envsubst  > $ASB_GIT_PATH/monitoring/03-grafana.yaml

```

#### Option 2: Prepare Grafana deployment for Azure Active Directory (AAD)

Deploy Grafana that uses AAD as the authentication mechanism. This process is a bit more involved as you will need to configure a Service Principal.

First, follow the steps detailed in the [Grafana documentation](https://grafana.com/docs/grafana/latest/auth/azuread/#create-the-azure-ad-application) to create the AAD Service Principal. Use the `ASB_DOMAIN` value as the `grafana domain` for the redirect URLs. Note the `TENANT_ID`, `CLIENT_ID` and `CLIENT_SECRET` values as you'll be needing these for the deployment template.

**Note**: The `CLIENT_SECRET` will be mounted from Key Vault and into the Grafana pod using Pod Identity. Rather than creating a whole new Managed Identity, Grafana makes use of NGSA's managed identity to grab the secret from Key Vault. Ensure that you have it setup by following the [Cosmos pod identity setup guide](../docs/cosmos.md#aad-pod-identity-setup-for-app).

Grafana with AAD will authorize users to the same AAD security group used to authorize users to the ASB cluster.

```bash

# Optional: Add client secret using AZ CLI
# You can also add it manually using the Azure portal with the secret name "grafana-aad-client-secret" [Recommended]

# Optional: give logged in user access to key vault
az keyvault set-policy --secret-permissions set --object-id $(az ad signed-in-user show --query objectId -o tsv) -n $ASB_KV_NAME -g $ASB_RG_CORE

# Optional: set grafana AAD client secrets
az keyvault secret set -o table --vault-name $ASB_KV_NAME --name "grafana-aad-client-secret" --value [insert CLIENT_SECRET]

# set grafana AAD ids
export ASB_GRAFANA_SP_CLIENT_ID=[insert CLIENT_ID]
export ASB_GRAFANA_SP_TENANT_ID=[insert TENANT_ID]
export ASB_GRAFANA_MI_NAME=grafana-id

# create grafana deployment file
cat templates/grafana-aad.yaml | envsubst  > $ASB_GIT_PATH/monitoring/03-grafana.yaml

# create grafana pod identity deployment file
cat templates/grafana-pod-identity.yaml | envsubst  > $ASB_GIT_PATH/monitoring/04-grafana-pod-identity.yaml

```

Add, commit and push the modified files using git to your working branch.

### Deploy Prometheus and Grafana

- Flux will pick up the latest changes. Use the command below to force flux to sync.
  
  ```bash
  
  fluxctl sync --k8s-fwd-ns flux-cd
  
  ```

### Configure Grafana using AAD

Ensure that you have added the proper users/groups in the Grafana's AAD service principal, the proper role mappings in the Manifest and [configured the `groupMembershipClaims`](https://grafana.com/docs/grafana/latest/auth/azuread/#configure-allowed-groups). If the pods are running, verify that you can access the grafana endpoint at `https://{ASB_DOMAIN}/grafana`. You should only see an option to sign in with Microsoft.

The login step may not work just yet, because the WAF can block the redirect requests from AAD to the grafana endpoint. If this is the case, add a firewall exclusion policy to avoid flagging these specific requests from AAD.

```bash

# create waf policy
export ASB_WAF_POLICY_NAME="${ASB_DEPLOYMENT_NAME}-waf-policy"

az network application-gateway waf-policy create -n $ASB_WAF_POLICY_NAME -g $ASB_RG_CORE

# create custom rule in waf policy
export ASB_WAF_POLICY_RULE="grafanaAADAuth"
export ASB_WAF_POLICY_RULE_PRIORITY="2"

az network application-gateway waf-policy custom-rule create \
  -n $ASB_WAF_POLICY_RULE --policy-name $ASB_WAF_POLICY_NAME -g $ASB_RG_CORE \
  --action Allow --priority $ASB_WAF_POLICY_RULE_PRIORITY --rule-type MatchRule

# add allow rule conditions for AAD redirect request
# add condition to check whether the redirectURI is going to /grafana/login/azuread 
az network application-gateway waf-policy custom-rule match-condition add \
  -n $ASB_WAF_POLICY_RULE --policy-name $ASB_WAF_POLICY_NAME -g $ASB_RG_CORE \
  --match-variables RequestUri --operator Contains --values "/grafana/login/azuread" \
  --transforms UrlDecode Lowercase

# use prevention mode and enable waf policy
az network application-gateway waf-policy policy-setting update \
  --policy-name $ASB_WAF_POLICY_NAME -g $ASB_RG_CORE --mode Prevention --state Enabled

# note the application gateway name in resource group
az network application-gateway list -g $ASB_RG_CORE --query "[].{Name:name}" -o tsv

```

**IMPORTANT**: With the WAF policy now created, you will need to associate this policy with the application gateway. Unfortunately, there currently isn't a way to do this using the AZ CLI. You can do this through the Azure portal by accessing the Application Gateway WAF policy in the core resource group, select `Associated application gateways` in the sidebar and `Add association` to the gateway name as you've noted in the last step above.

### Verify Prometheus Service

- Check that it worked by running: `kubectl port-forward service/prometheus-service 9090:8080 -n monitoring`
- Navigate to localhost:9090 in your browser. You should see a Prometheus query page.

### Verify Grafana Service

- Check that it worked by running the following: kubectl port-forward service/grafana 3000:3000 -n monitoring
- Navigate to localhost:3000 in your browser. You should see a Grafana login page.
- If you setup Grafana using basic auth, use admin for both the username and password to login.
- If you setup Grafana using AAD, sign in using Microsoft. If you cannot access Grafana, check if you are added as a user/group member in the Grafana AAD Service Principal. If you encounter a `403` from the Application gateway, ensure the WAF policy conditions are accurate and is associated with the application gateway.

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

## Prometheus Design Notes

- The Prometheus container runs as a non-root user and requires write permissions on a mounted volume. We used initContainers to change the ownership of the datastore directory.
