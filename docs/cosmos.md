# Cosmos DB in AKS secure baseline

Prerequisites:

* A CosmosDB movie database is required, Follow setup instructions in [README.md](https://github.com/cse-labs/imdb) to create a new environment

## Set Cosmos environment variables

```bash

export ASB_COSMOS_RG_NAME="[Cosmos resource group name]" # e.g rg-ngsa-asb-shared
export ASB_COSMOS_DB_NAME="[Cosmos account name]" # e.g ngsa-asb-cosmos
export ASB_IMDB_DB="imdb"
export ASB_IMDB_COL="movies"
export ASB_IMDB_RW_KEY="az cosmosdb keys list -n $ASB_COSMOS_DB_NAME -g $ASB_COSMOS_RG_NAME --query primaryMasterKey -o tsv"
export ASB_COSMOS_ID=$(az cosmosdb show -g $ASB_COSMOS_RG_NAME -n $ASB_COSMOS_DB_NAME --query id -o tsv)

# save env vars
./saveenv.sh -y

```

## Setup private connection

```bash

# get id for common services subnet
export ASB_HUB_CS_SUBNET_ID=$(az network vnet subnet show -g $ASB_RG_HUB -n CommonServicesSubnet --vnet-name vnet-${ASB_HUB_LOCATION}-hub --query id -o tsv)

# create private endpoint
az network private-endpoint create \
  --name "nodepools-to-cosmos" \
  --connection-name "nodepools-to-cosmos-connection" \
  --resource-group $ASB_RG_CORE \
  --subnet $ASB_HUB_CS_SUBNET_ID \
  --private-connection-resource-id $ASB_COSMOS_ID \
  --group-id "Sql"

# create private dns zone
# recommended zone names: https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration
export ASB_COSMOS_ZONE="privatelink.documents.azure.com"
az network private-dns zone create --resource-group $ASB_RG_CORE --name $ASB_COSMOS_ZONE

# Create vnet link between private zone and hub vnet
az network private-dns link vnet create \
  --resource-group $ASB_RG_CORE \
  --zone-name  $ASB_COSMOS_ZONE \
  --name "to_vnet-${ASB_HUB_LOCATION}-hub" \
  --virtual-network $ASB_HUB_VNET_ID \
  --registration-enabled false

# Create a DNS zone group to add cosmos dns records to private dns zone
az network private-endpoint dns-zone-group create \
  --resource-group $ASB_RG_CORE \
  --endpoint-name "nodepools-to-cosmos" \
  --name "nodepools-to-cosmos-zone-group" \
  --private-dns-zone $ASB_COSMOS_ZONE \
  --zone-name $ASB_DEPLOYMENT_NAME

# Create vnet link between private zone and spoke vnet
az network private-dns link vnet create \
  --resource-group $ASB_RG_CORE \
  --zone-name  $ASB_COSMOS_ZONE \
  --name "to_vnet-spoke-${ASB_ORG_APP_ID_NAME}-00" \
  --virtual-network $ASB_SPOKE_VNET_ID \
  --registration-enabled false

# Save environment variables
./saveenv.sh -y

```

## Add app secrets to key vault

```bash

# give logged in user access to key vault
az keyvault set-policy --secret-permissions set --object-id $(az ad signed-in-user show --query objectId -o tsv) -n $ASB_KV_NAME -g $ASB_RG_CORE

# set app secrets
az keyvault secret set -o table --vault-name $ASB_KV_NAME --name "CosmosDatabase" --value $ASB_IMDB_DB
az keyvault secret set -o table --vault-name $ASB_KV_NAME --name "CosmosCollection" --value $ASB_IMDB_COL
az keyvault secret set -o table --vault-name $ASB_KV_NAME --name "CosmosKey" \
  --value $(az cosmosdb keys list -n $ASB_COSMOS_DB_NAME -g $ASB_COSMOS_RG_NAME --query primaryMasterKey -o tsv)
az keyvault secret set -o table --vault-name $ASB_KV_NAME --name "CosmosUrl" --value "https://${ASB_COSMOS_DB_NAME}.documents.azure.com:443/"

# remove logged in user's access to key vault
az keyvault delete-policy --object-id $(az ad signed-in-user show --query objectId -o tsv) -n $ASB_KV_NAME -g $ASB_RG_CORE

```

## Monitoring

Enable Azure Diagnostics for Cosmos to send logs and metrics to Log Analytics.

* Go to the Cosmos database in the portal
* Click on Diagnostic settings in the sidebar under the Monitoring section
* Click Add diagnostic setting link
* Fill in the setting details
  * choose a name
  * choose DataPlaneRequests under Logs > Categories
  * choose Request under Metrics
  * choose Send to Log Analytics workspace under Destination details
  * choose the appropriate log subscription and log analytics
  * choose AzureDiagnostics under Destination Table
* Click save
