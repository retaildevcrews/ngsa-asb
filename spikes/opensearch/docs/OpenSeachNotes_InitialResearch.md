# Spike: Open Search for the Cosmos Query Scaling Layer



## Install OpenSearch locally via Codespaces

Steps taken:

1. Create local implementation using K3D and Codespaces

|Setting Name|Old Value|New Value|Command or Code|Reasons|
| --- | --- | --- | --- | --- |
| vm.max_map_count | 262144 | 65530 | sudo sysctl -w vm.max_map_count=262144 | Increase virtual memory.  Rrequired for OpenSearch |
| Codespaces Memory  | 4 Gb  | 16 Gb   |   | Increased the overall memory for environment to prevent crashing.  |

## References & Assets

- [OpenSearch-k8s-Operator - How To](https://opensearch.org/docs/latest/tools/k8s-operator/#use-a-local-installation)

- [OpenSearch-k8s-Operator Reposiory](https://github.com/Opster/opensearch-k8s-operator)

- [Open Search K8s Indexing Data](https://opensearch.org/docs/latest/opensearch/index-data/)

## Instructions for CodeSpace Implemenation

1. Create Codespace for NGSA-App
2. Using Terminal run the following Commands:

      ### Create/Stand up K3D within CodeSpaces

      The below instructions will create a local K3D environment for Kuberentes testing and validation.

      #### Make Instructions to Create K3d Environment

      ```bash
      # Establishes the K3D cluster based on Codespaces settings
      make All 

      # Not technically neeeded
      make deploy-ngsa-memory 

      # Verify K3D is up and clean.
      make check
      ```

## in the Terminal

From the Visual Studio Code (VSCode) environment opened to NGSA-App please navigate to the workspace folder and create the following directories using the code listed below.

| Directory | Directory to Create | Command | Why? |
| --- | --- | --- | --- |
| ./workspace | Repositories | mkdir Repositories | To hold OpenSearch Repositories pulled locally. |
| ./workspace/Repositories | OpenSearch | mkdir OpenSearch | To hold OpenSearch Repository files. |

### Set the vm.max_map_count to OpenSearch's Requirements

``` bash
# increase the vm.max_map_count to the setting required for OpenSearch
sudo sysctl -w vm.max_map_count=262144
```

### Code sample to create K3D in Codespaces

``` bash
cd ../
mkdir repo
cd repo
mkdir OpenSearch
cd OpenSearch
```

### Cloning OpenSearch K8s Operator

``` bash
#clone the repository into the correct directory OpenSearch
git clone https://github.com/Opster/opensearch-k8s-operator
```

### Install the chart using HELM

``` bash
# use HELM to add a repository for Open Search K8s Operator
helm repo add opensearch-operator https://opster.github.io/opensearch-k8s-operator/

# use HELM cli to list the open search repository to make sure it was added successfully.  
helm repo list | grep opensearch

# use HELM cli to install the chart
helm install opensearch-operator opensearch-operator/opensearch-operator

```

### Package the HELM chart

``` bash

# find the Helm chart located in the charts dirtory.
cd /opensearch-operator/charts

# Call Helm's cli to package the charts and values into a tgz file.
helm package .
```

### Create Kubernetes Namespace

``` bash

# check if the potential namespace exists
NAMESPACE="open-search"

EXISTS=$(kubectl get namespace "$NAMESPACE" 2>&1)

if [ "$EXISTS" == "Error from server (NotFound): namespaces \"$NAMESPACE\" not found" ]; then
  kubectl create namespace open-search
else
  echo "Namespace $NAMESPACE exists."
fi
```

### Install the tgz file using Helm

``` bash
# Installing the helm chart
helm install --set name=OpenSearchOperator open-search-operator open-search-operator-2.2.0.tgz  --namespace $NAMESPACE
```

### Verify the tgz file is Operationg Correctly

```bash
# check to see if the Helm deployment of chart install worked correctly with kubectl
k get deployments -A

# check to see if the Helm pods of chart install worked correctly with kubectl
k get pods -A

# check to see if the Helm chart install worked correctly with k9s
k9s 
```

### Install Open Search Cluster

``` bash
# Change directories to the examples directory the location yaml
cd ../../opensearch-operator/examples

# using kubectl apply the opensearch cluster yaml
kubectl apply -f opensearch-cluster.yaml
```

### Port forward Dashboard

- <span style="color:red;">**TODO:** fix port forward, should I use svc?</span>
- <span style="color:orange;">**INFO:** currently forwarded using VSCode</span>

``` bash
# Port forward 5601 to dashbaord
kubectl port-forward svc/open-search-cluster-dashboards 5601
```

## Istio Confiruation

Create Istio Gateway & Virtual Service.
- <span style="color:red;">**TODO:** Verify that the virtual service wasn't already created.</span>

``` yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: booking-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: booking
spec:
  hosts:
  - "*"
  gateways:
  - booking-gateway
  http:
  - match:
    - uri:
        prefix: /api/v1/booking
    route:
    - destination:
        host: booking-service
        port:
          number: 8080

```

<span style="color:red;">**TODO:** Investigate if the below configure will route search data.</span>

``` yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: shipping-service
spec:
  hosts:
    - shipping-service
  http:
  - route:
    - destination:
        host: shipping-service
        subset: v1
      weight: 90
    - destination:
        host: shipping-service
        subset: v2
      weight: 10
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: shipping-service
spec:
  host: shipping-service
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```


## Intalling on a Cluster

- <span style="color:red;"> **TODO:**</span>

### CPU Settings

- <span style="color:red;">**TODO:**</span>

#### Helm Chart

- <span style="color:red;">**TODO:**</span>

#### Yaml File in Examples

- <span style="color:red;">**TODO:**</span>

### Memory Settings

- <span style="color:red;">**TODO:**</span>

## Indexing Sources

### Creating an OpenSearch Pipeline

``` yaml
pipeline:
  name: index_cosmos
  actions:
    - type: cosmosdb
      name: extract_data
      connection_string: <COSMOS_DB_CONNECTION_STRING>
      database_id: <COSMOS_DB_DATABASE_ID>
      collection_id: <COSMOS_DB_COLLECTION_ID>
      query: SELECT * FROM c
    - type: index
      name: index_data
      data_source: extract_data
      index: <OPENSEARCH_INDEX_NAME>
      api_key: <OPENSEARCH_API_KEY>
```

``` bash
opensearch pipeline run index_cosmos
```

``` bash
# Indexing data via rest endpooint for bulk updates.  
curl -H "Content-Type: application/x-ndjson" -POST https://localhost:9200/data/_bulk -u 'admin:admin' --insecure --data-binary "@data.json"
```

- <span style="color:red;">**TODO:**</span>

### Log Analytics

- <span style="color:red;">**TODO:**</span>

``` bash
#!/bin/bash

# Define the Log Analytics workspace and query
workspace_id="<LOG_ANALYTICS_WORKSPACE_ID>"
query='<LOG_ANALYTICS_QUERY>'

# Define the OpenSearch endpoint and API key
endpoint="https://api.opensearch.io/v1/indexes/<OPENSEARCH_INDEX_NAME>/docs/batch"
api_key="<OPENSEARCH_API_KEY>"

# Function to update the OpenSearch index with the latest logs from Log Analytics
update_index() {
  # Get the logs from Log Analytics
  logs=$(az log analytics query --workspace-id $workspace_id --query "$query" --output tsv)

  # Create a JSON array of the logs to be indexed
  log_array=$(echo "$logs" | awk -F $'\t' '{print "{\"timestamp\":\""$1"\",\"message\":\""$2"\"}"}' | jq -R -s -c 'split("\n")')

  # Index the logs in OpenSearch
  curl -X POST $endpoint \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d "$log_array"
}

# Function to search for errors in the OpenSearch index
search_for_error() {
  # Define the search query and endpoint
  query="error"
  search_endpoint="https://api.opensearch.io/v1/search"

  # Encode the query for use in the URL
  query_encoded=$(echo "$query" | jq -R -s -r @uri)

  # Make the search request
  response=$(curl -X GET "$search_endpoint?q=$query_encoded" -H "Authorization: Bearer $api_key" -H "Content-Type: application/json")

  # Print the response
  echo "$response"
}

# Call the update_index function to initially populate the OpenSearch index
update_index

# Continuously update the OpenSearch index every hour
while true; do
  update_index
  sleep 3600
done
```

### Files in Blob Location

``` bash
#!/bin/bash

# Define the Blob storage account and container name
account_name="<BLOB_STORAGE_ACCOUNT_NAME>"
container_name="<BLOB_STORAGE_CONTAINER_NAME>"

# Define the OpenSearch endpoint and API key
endpoint="https://api.opensearch.io/v1/indexes/<OPENSEARCH_INDEX_NAME>/docs/batch"
api_key="<OPENSEARCH_API_KEY>"

# Function to update the OpenSearch index with the latest contents of the Blob storage location
update_index() {
  # Get a list of the Blob storage files
  files=$(az storage blob list --account-name $account_name --container-name $container_name --query '[].{name:name}' --output tsv)

  # Loop through each file, get its contents, and index it in OpenSearch
  while read -r file; do
    contents=$(az storage blob show --account-name $account_name --container-name $container_name --name "$file" --query 'content' --output tsv)
    curl -X POST $endpoint \
      -H "Authorization: Bearer $api_key" \
      -H "Content-Type: application/json" \
      -d "{\"filename\":\"$file\",\"contents\":\"$contents\"}"
  done <<< "$files"
}

# Function to search for a specific string in the OpenSearch index
search_for_string() {
  # Define the search string and endpoint
  search_string="<SEARCH_STRING>"
  search_endpoint="https://api.opensearch.io/v1/search"

  # Encode the search string for use in the URL
  search_string_encoded=$(echo "$search_string" | jq -R -s -r @uri)

  # Make the search request
  response=$(curl -X GET "$search_endpoint?q=$search_string_encoded" -H "Authorization: Bearer $api_key" -H "Content-Type: application/json")

  # Print the response
  echo "$response"
}

# Call the update_index function to initially populate the OpenSearch index
update_index

# Continuously update the OpenSearch index every hour
while true; do
  update_index
  sleep 3600
done

```

- <span style="color:red;">**TODO:**</span>

### Cosmos DB Sources

Using the pipeline create above.

``` bash
#!/bin/bash

# Define endpoint and API key
endpoint="https://api.opensearch.io/v1/search"
api_key="<OPENSEARCH_API_KEY>"
index="<OPENSEARCH_INDEX_NAME>"
query="<SEARCH_QUERY>"

# Encode the query for use in the URL
query_encoded=$(echo "$query" | jq -R -s -r @uri)

# Make the search request
response=$(curl -X GET "$endpoint?q=$query_encoded" -H "Authorization: Bearer $api_key" -H "Content-Type: application/json")

# Print the response
echo "$response"

```

- <span style="color:red;">**TODO:**</span>

### Alaising Indexes

- <span style="color:red;">**TODO:**</span>

## Placing items in GHCR.io

- <span style="color:red;">**TODO:** Investigate if opensearchproject is the correct location/container repository.</span>

```bash
# pulling docker image from the latest version located at opensearchproject/opensearch
docker pull opensearchproject/opensearch:latest
docker pull opensearchproject/opensearch-dashboards:latest

# exporting the PAT to a variable.
export CR_PAT=<YOUR-PAT>;

# securly passing in the Container Registry Personal Access Token (PAT) using stdin
echo $CR_PAT | docker login ghcr.io -u trfalls@microsoft.com --password-stdin

# tag Open Search
docker image tag opensearchproject/opensearch:latest

# Github container registry 
# ghcr.io/retaildevcrews/opensearchproject/opensearch:latest

# push the tagged image to the Github Retail Devcrews container registry
docker push ghcr.io/retaildevcrews/opensearchproject/opensearch:latest

# tag dashboards
docker image tag opensearchproject/opensearch-dashboards:latest

# Github container registry 
# ghcr.io/retaildevcrews/opensearchproject/opensearch-dashboards:latest

# push the tagged image to the Github Retail Devcrews container registry
docker push ghcr.io/retaildevcrews/opensearchproject/opensearch-dashboards:latest
```

## Conclusion to Spike

- <span style="color:red;">**TODO:** Spell out the goals and findings</span>
