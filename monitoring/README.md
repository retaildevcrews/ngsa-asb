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

export ASB_ACR_NAME=$(az deployment group show -g $ASB_RG_CORE -n cluster-${ASB_DEPLOYMENT_NAME}-${ASB_CLUSTER_LOCATION}  --query properties.outputs.containerRegistryName.value -o tsv)

# import Prometheus into ACR
az acr import --source docker.io/prom/prometheus:v2.30.0 -n $ASB_ACR_NAME

# import Grafana into ACR
az acr import --source docker.io/grafana/grafana:8.5.5 -n $ASB_ACR_NAME

# import Thanos into ACR
az acr import --source quay.io/thanos/thanos:v0.23.0 -n $ASB_ACR_NAME

```

### Thanos setup

#### Create Azure Storage Account

Create a storage account in the shared core resource group. Storage account names are limited to lowercase letters and numbers. <https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftstorage>.

```bash

# Check if storage account name is available and is a valid name
export ASB_THANOS_STORAGE_ACCOUNT_NAME="sangsaasb$ASB_ENV"
az storage account check-name --name $ASB_THANOS_STORAGE_ACCOUNT_NAME

# Create storage account
az storage account create \
  --name $ASB_THANOS_STORAGE_ACCOUNT_NAME \
  --resource-group $ASB_RG_CORE \
  --location $ASB_HUB_LOCATION

# Create Storage Container for Thanos
az storage container create \
  --name metrics \
  --account-name $ASB_THANOS_STORAGE_ACCOUNT_NAME \
  --account-key "$(az storage account keys list -g $ASB_RG_CORE -n $ASB_THANOS_STORAGE_ACCOUNT_NAME --query [0].value -o tsv)"

# Save environment variables
./saveenv.sh

```

#### Setup secret configuration

The Thanos configuration has a secret for accessing the storage account. This will be saved to the environment key vault for future use.

```bash

# Generate secret config from template and save to keyvault
THANOS_KV_SET_COMMAND='AZURE_STORAGE_ACCOUNT_KEY=$(az storage account keys list -g $ASB_RG_CORE -n $ASB_THANOS_STORAGE_ACCOUNT_NAME --query [0].value -o tsv) envsubst < monitoring/template/thanos-storage-config.yaml.tmpl'
az keyvault secret set --name "thanos-storage-config" --vault-name $ASB_KV_NAME --value "$(eval $THANOS_KV_SET_COMMAND)"

```

> Note: Create the Kubernetes secret resource in all the clusters for the environment.

```bash

# create monitoring namespace if it does not exist already
kubectl create namespace monitoring

# Create k8s secret for Thanos components
kubectl create secret generic thanos-objstore-config \
  --from-literal="thanos-storage-config.yaml=$(az keyvault secret show --name "thanos-storage-config" --vault-name $ASB_KV_NAME --query value -o tsv)" \
  -n monitoring

```

#### Setup private DNS

Create DNS records in the private DNS zone to allow cross cluster communication

```bash

export ASB_AKS_PRIVATE_IP="$ASB_SPOKE_IP_PREFIX".4.4

az network private-dns record-set a add-record \
  -g $ASB_RG_CORE \
  -z $ASB_DNS_ZONE \
  -n "thanos-grpc-${ASB_SPOKE_LOCATION}-${ASB_ENV}" \
  -a $ASB_AKS_PRIVATE_IP \
  --query fqdn

az network private-dns record-set a add-record \
  -g $ASB_RG_CORE \
  -z $ASB_DNS_ZONE \
  -n "thanos-store-grpc-${ASB_SPOKE_LOCATION}-${ASB_ENV}" \
  -a $ASB_AKS_PRIVATE_IP \
  --query fqdn

```

### Create Deployment Templates

```bash

mkdir $ASB_GIT_PATH/monitoring
# create monitoring namespace deployment file
cp templates/monitoring/01-namespace.yaml $ASB_GIT_PATH/monitoring/01-namespace.yaml
# create prometheus deployment file
cat templates/monitoring/02-prometheus.yaml | envsubst  > $ASB_GIT_PATH/monitoring/02-prometheus.yaml

```

> 🛑 **Important**:
>
> This step is only required for the Thanos observer cluster.
>
> Skip this section for all other clusters.

```bash

mkdir -p  $ASB_GIT_PATH/monitoring/thanos

# create thanos querier deployment file
cat templates/monitoring/thanos/thanos-querier.yaml | envsubst  > $ASB_GIT_PATH/monitoring/thanos/thanos-querier.yaml

# create thanos store deployment file
cat templates/monitoring/thanos/thanos-store.yaml | envsubst > $ASB_GIT_PATH/monitoring/thanos/thanos-store.yaml

# create thanos compactor deployment file
cat templates/monitoring/thanos/thanos-compactor.yaml | envsubst > $ASB_GIT_PATH/monitoring/thanos/thanos-compactor.yaml

```

### Prepare Grafana deployment for Azure Active Directory (AAD)

Deploy Grafana that uses AAD as the authentication mechanism.

First, follow the steps detailed in the [Grafana documentation](https://grafana.com/docs/grafana/latest/auth/azuread/#create-the-azure-ad-application) to create the AAD Service Principal. Use the `ASB_DOMAIN` value as the `grafana domain` for the redirect URLs. Note the `TENANT_ID`, `CLIENT_ID` and `CLIENT_SECRET` values as you'll be needing these for the deployment template.

**Note**: The `CLIENT_SECRET` will be mounted from Key Vault and into the Grafana pod using Pod Identity. Rather than creating a whole new Managed Identity, Grafana makes use of NGSA's managed identity to grab the secret from Key Vault. Ensure that you have it setup by following the [Cosmos pod identity setup guide](../docs/cosmos.md#aad-pod-identity-setup-for-app).

You'll need to run a few more steps to completely setup the AAD Service Principal.

1. Navigate to the Service Principal you created in AAD -> Enterprise Applications. Search for your application and click on it.
2. If you haven't added the users already, go ahead and add them in the "Users and groups" menu from the sidebar.
3. Go to "Properties", select "Yes" for the "Assignment required?" option and save. This ensures users only assigned to the Service Principal can access Grafana.

### Setup Grafana deployment templates

🛑 The current setup for Grafana uses the default sqlite database for storage. In order to run multiple pods, a shared storage setup should be investigated. With this constraint, Grafana should only have 1 replica. More information here <https://grafana.com/docs/grafana/latest/setup-grafana/set-up-for-high-availability>.

```bash

# Optional: Add client secret using AZ CLI
# You can also add it manually using the Azure portal with the secret name "grafana-aad-client-secret" [Recommended]

# Give logged in user access to key vault
az keyvault set-policy --secret-permissions set --object-id $(az ad signed-in-user show --query id -o tsv) -n $ASB_KV_NAME -g $ASB_RG_CORE

# Set grafana AAD client secrets
az keyvault secret set -o table --vault-name $ASB_KV_NAME --name "grafana-aad-client-secret" --value [insert CLIENT_SECRET]

# set grafana AAD ids
export ASB_GRAFANA_SP_CLIENT_ID=[insert CLIENT_ID]
export ASB_GRAFANA_SP_TENANT_ID=[insert TENANT_ID]
export ASB_GRAFANA_MI_NAME=grafana-id

# create grafana-config config-map file
cat templates/monitoring/grafana/01-grafana-config.yaml | envsubst  > $ASB_GIT_PATH/monitoring/grafana/01-grafana-config.yaml

# create grafana-datasources config-map file
cat templates/monitoring/grafana/02-grafana-config-datasources.yaml | envsubst  > $ASB_GIT_PATH/monitoring/grafana/02-grafana-config-datasources.yaml

# create grafana-dashboard-providers config-map file
cat templates/monitoring/grafana/03-grafana-config-dashboards.yaml | envsubst  > $ASB_GIT_PATH/monitoring/grafana/03-grafana-config-dashboards.yaml

# create AzureIdentity, AzureIdentityBinding, SecretProviderClass file
cat templates/monitoring/grafana/04-grafana-pod-identity.yaml | envsubst  > $ASB_GIT_PATH/monitoring/grafana/04-grafana-pod-identity.yaml

# IMPORTANT: dashboard yaml files are not in templates
# create manually and place in $ASB_GIT_PATH/monitoring/grafana/dashboards

# create Deployment, Service, VirtualService file
cat templates/monitoring/grafana/05-grafana.yaml | envsubst  > $ASB_GIT_PATH/monitoring/grafana/05-grafana.yaml

```

Add, commit and push the modified files using git to your working branch.

### Deploy Prometheus and Grafana

- Flux will pick up the latest changes. Use the command below to force flux to sync.

  ```bash

  flux reconcile kustomization -n monitoring monitoring

  ```

### Add Grafana Listener to application gateway

```bash
# app DNS name, in subdomain format
# format [app]-[region]-[env].cse.ms
export ASB_APP_NAME=grafana
export ASB_APP_DNS_NAME=${ASB_APP_NAME}-${ASB_SPOKE_LOCATION}-${ASB_ENV}
export ASB_APP_DNS_FULL_NAME=${ASB_APP_DNS_NAME}.${ASB_DNS_ZONE}
export ASB_APP_HEALTH_ENDPOINT="/api/health"

# create record for public facing DNS
az network dns record-set a add-record -g $ASB_DNS_ZONE_RG -z $ASB_DNS_ZONE -n $ASB_APP_DNS_NAME -a $ASB_AKS_PIP --query fqdn

# create record for private DNS zone
export ASB_AKS_PRIVATE_IP="$ASB_SPOKE_IP_PREFIX".4.4
az network private-dns record-set a add-record -g $ASB_RG_CORE -z $ASB_DNS_ZONE -n $ASB_APP_DNS_NAME -a $ASB_AKS_PRIVATE_IP --query fqdn

# create app gateway resources
# backend pool, HTTPS listener (443), health probe, http setting and routing rule
export ASB_APP_GW_NAME="apw-$ASB_AKS_NAME"

az network application-gateway address-pool create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n $ASB_APP_DNS_FULL_NAME --servers $ASB_APP_DNS_FULL_NAME

az network application-gateway http-listener create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "listener-$ASB_APP_DNS_NAME" --frontend-port "apw-frontend-ports" --ssl-cert "$ASB_APP_GW_NAME-ssl-certificate" \
  --host-name $ASB_APP_DNS_FULL_NAME

az network application-gateway probe create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "probe-$ASB_APP_DNS_NAME" --protocol https --path $ASB_APP_HEALTH_ENDPOINT \
  --host-name-from-http-settings true --interval 30 --timeout 30 --threshold 3 \
  --match-status-codes "200-399"

az network application-gateway http-settings create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "$ASB_APP_DNS_NAME-httpsettings" --port 443 --protocol Https --cookie-based-affinity Disabled --connection-draining-timeout 0 \
  --timeout 20 --host-name-from-backend-pool true --enable-probe --probe "probe-$ASB_APP_DNS_NAME"

az network application-gateway rule create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "$ASB_APP_DNS_NAME-routing-rule" --address-pool $ASB_APP_DNS_FULL_NAME \
  --http-settings "$ASB_APP_DNS_NAME-httpsettings" --http-listener "listener-$ASB_APP_DNS_NAME"

# set http redirection
# create listener for HTTP (80), HTTPS redirect config and HTTPS redirect routing rule
az network application-gateway http-listener create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "http-listener-$ASB_APP_DNS_NAME" --frontend-port "apw-frontend-ports-http" --host-name $ASB_APP_DNS_FULL_NAME

az network application-gateway redirect-config create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "https-redirect-config-$ASB_APP_DNS_NAME" -t "Permanent" --include-path true \
  --include-query-string true --target-listener "listener-$ASB_APP_DNS_NAME"

az network application-gateway rule create -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME \
  -n "https-redirect-$ASB_APP_DNS_NAME-routing-rule" --http-listener "http-listener-$ASB_APP_DNS_NAME" \
  --redirect-config "https-redirect-config-$ASB_APP_DNS_NAME"

```

### Configure Grafana using AAD

Ensure that you have added the proper users/groups in the Grafana's AAD service principal, the proper role mappings in the Manifest and [configured the `groupMembershipClaims`](https://grafana.com/docs/grafana/latest/auth/azuread/#configure-allowed-groups). If the pods are running, verify that you can access the grafana endpoint at `https://{ASB_APP_DNS_FULL_NAME}`. You should only see an option to sign in with Microsoft.

The login step may not work just yet, because the WAF can block the redirect requests from AAD to the grafana endpoint. If this is the case, add a firewall exclusion policy to avoid flagging these specific requests from AAD.

```bash

# create waf policy
export ASB_WAF_POLICY_NAME="${ASB_DEPLOYMENT_NAME}-waf-policy-${ASB_SPOKE_LOCATION}"

az network application-gateway waf-policy create -n $ASB_WAF_POLICY_NAME -g $ASB_RG_CORE -l $ASB_SPOKE_LOCATION

# create custom rule in waf policy for grafana AAD
export ASB_WAF_POLICY_RULE_AAD="grafanaAADAuth"
export ASB_WAF_POLICY_RULE_PRIORITY_AAD="2"

az network application-gateway waf-policy custom-rule create \
  -n $ASB_WAF_POLICY_RULE_AAD --policy-name $ASB_WAF_POLICY_NAME -g $ASB_RG_CORE \
  --action Allow --priority $ASB_WAF_POLICY_RULE_PRIORITY_AAD --rule-type MatchRule

# add allow rule conditions for AAD redirect request
# add condition to check whether the redirectURI is going to /login/azuread
az network application-gateway waf-policy custom-rule match-condition add \
  -n $ASB_WAF_POLICY_RULE_AAD --policy-name $ASB_WAF_POLICY_NAME -g $ASB_RG_CORE \
  --match-variables RequestUri --operator Contains --values "/login/azuread" \
  --transforms UrlDecode Lowercase

# create custom rule in waf policy for grafana to read from prometheus
export ASB_WAF_POLICY_RULE_PROM="prometheusQuery"
export ASB_WAF_POLICY_RULE_PRIORITY_PROM="4"

az network application-gateway waf-policy custom-rule create \
  -n $ASB_WAF_POLICY_RULE_PROM --policy-name $ASB_WAF_POLICY_NAME -g $ASB_RG_CORE \
  --action Allow --priority $ASB_WAF_POLICY_RULE_PRIORITY_PROM --rule-type MatchRule

# add allow rule conditions for AAD redirect request
# add condition to check whether the redirectURI is going to /api/datasources
az network application-gateway waf-policy custom-rule match-condition add \
  -n $ASB_WAF_POLICY_RULE_PROM --policy-name $ASB_WAF_POLICY_NAME -g $ASB_RG_CORE \
  --match-variables RequestUri --operator Contains --values "/api/datasources" \
  --transforms UrlDecode Lowercase


# use prevention mode and enable waf policy
az network application-gateway waf-policy policy-setting update \
  --policy-name $ASB_WAF_POLICY_NAME -g $ASB_RG_CORE --mode Prevention --state Enabled

# note the application gateway name in resource group
az network application-gateway list -g $ASB_RG_CORE --query "[].{Name:name}" -o tsv

```

**IMPORTANT**: With the WAF policy now created, you will need to associate this policy with the application gateway's http listener. Unfortunately, there currently isn't a way to do this using the AZ CLI. You can do this through the Azure portal by accessing the Application Gateway WAF policy in the core resource group, select `Associated application gateways` in the sidebar and `Add association` to the gateway name as you've noted in the last step above. Add both grafana's HTTP and HTTPS listeners

### Verify Prometheus Service

- Check that it worked by running: `kubectl port-forward service/prometheus-server 9090:9090 -n monitoring`
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

- Go to Azure Active Directory --> App Registration
- Click New Registration and enter `<your-service-principal-name>`
  - Select option "Accounts in this organizational directory only (Microsoft only - Single tenant)"
  - Click Register, this will open up the App registrations settings screen.
- From App registrations settings --> Certificates and Secrets
  - Create a new Client secret, this will be use later to configure Azure Monitor in grafana
  - Save the secret to key vault for later use

### Assign a role to the application (Portal)

The Grafana service principal needs read access to Log Analytics and Cosmos. Add the Reader permission for the core resource group, hub resource group, and the Cosmos resource group.

- Go to resource group `<your-resource-group>` --> Access Control (IAM) --> Role Assignments
- Look for and add the service principal created `<your-service-principal-name>` as "Reader"

## Add Azure Monitor Source in Grafana

Get access to Grafana dashboard

Go to a browser to access grafana and perform the following steps:

- Go to Configuration --> Data Sources
- "Add data source" --> Select "Azure Monitor"
- Inside "Azure Monitor" Source
  - Under Azure Monitor Details
    - Put in Directory (Tenant) ID, Application (Client) ID (service principal `<your-service-principal-name>` ID) and Client Secret from [Add a secret to the service principal](#add-a-secret-to-the-service-principal)
    - Click on "Load Subscription" --> After loading, select proper subscription from drop-down
    - Click Load Workspaces
    - Select the Log analytics for environment you want to monitor
    - Click Save & Test
- Click on "Explore" from Grafana side bar
- Try out different metrics and services

In our installation of Grafana, we have removed the persistent volume and import the dashboards, data sources by mounting configmaps. To ensure that the Azure Monitor data source plugin persists through restarts, you will need to add the client secret in Key Vault and import the secret using the CSI Driver.

## Import Grafana dashboard JSON file into Grafana

- Navigate to localhost:3000 in your browser to get Grafana login page
- Go to `Dashboards` > `Manage` page from left menu
- Click `Import`
- Upload dashboard file [ngsa-dev-model.json](../monitoring/dashboards/ngsa-dev-model.json)

## Setup Alerts

- Please reference the [alerts documentation](./alerts/README.md) for instructions on setting up alerts.

## Prometheus Design Notes

- The Prometheus container runs as a non-root user and requires write permissions on a mounted volume. We used initContainers to change the ownership of the datastore directory.

- In our experience, Prometheus pods have occasionally run out of memory. To reduce the memory footprint, we enforced a metrics retention size of 3900MB and only included the NGSA/LR apps in the scrape configs. In addition, we increased the metrics scrape interval to 15s. However, this will reduce the granularity of metrics within Prometheus/Grafana. We will look to integrate Thanos to resolve this issue, since it flushes the Prometheus metrics into a long running Azure block storage container.
