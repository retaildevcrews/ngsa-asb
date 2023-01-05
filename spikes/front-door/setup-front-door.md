# Azure Front Door Setup Instructions

## Summary

After deploying your clusters using the AKS Secure Baseline method outlined in this repository, [Azure Front Door](https://azure.microsoft.com/en-us/products/frontdoor/#documentation) can also be used as a global load balancer for your deployed apps. For example, if you have ***ngsa-memory*** deployed on different clusters in different regions, each with a distinct public endpoint, i.e., ***ngsa-memory-eastus-dev.cse.ms*** and ***ngsa-memory-westus3-dev.cse.ms*** you can create a single front end (***ngsa-memory-dev.cse.ms***, perhaps) for both instances using Azure Front Door. The Azure CLI setup instructions to create and deploy Azure Front Door as a global load balancer are included below, using ngsa-memory as an example. In summary, we

- create and configure the Azure Front Door resource
- create a front end endpoint
- create a backend pool and add all backend addresses to it
- create a routing rule to connect the front end endpoint to the backend pool

Steps 2, 4, 5 and 6 shown below will need to be repeated for every additional application (e.g., loderunner, ngsa-java, ngsa-cosmos) we want to set up with a global front end endpoint through Front Door.

## Step 1: Create the Azure Front Door resource

```bash
# create resource group for Front Door
export ASB_ENV=dev
export ASB_FD_ROOT_NAME=ngsa
export ASB_FD_NAME=${ASB_FD_ROOT_NAME}-${ASB_ENV}
export ASB_FD_RG_NAME=rg-front-door-${ASB_FD_NAME}
export ASB_FD_LOCATION=northcentralus

az group create --name $ASB_FD_RG_NAME --location $ASB_FD_LOCATION

# create Azure Front Door resource
export ASB_DNS_ZONE_RG=dns-rg
export ASB_DNS_ZONE=cse.ms
export ASB_NGSA_APP=memory
export ASB_FD_BACKEND_ADDRESS=${ASB_FD_ROOT_NAME}-${ASB_NGSA_APP}-${ASB_FD_LOCATION}-${ASB_ENV}.${ASB_DNS_ZONE}

az network front-door create \
    --resource-group $ASB_FD_RG_NAME \
    --name $ASB_FD_NAME \
    --accepted-protocols Https \
    --backend-address $ASB_FD_BACKEND_ADDRESS
```

## Step 2: Create DNS record set

The Azure Front Door URL is automatically generated when the Front Door resource is created. It can be seen on the Azure Front Door resource's overview page in the Azure portal. The record set name is the URL name we want to assign to our global front end. Both of these values will be needed to create the CNAME DNS record set for our global front end endpoint.

```bash
# create CNAME record aliased to Azure Front Door URL
export ASB_CNAME_RECORD_SET_NAME=${ASB_FD_ROOT_NAME}-${ASB_NGSA_APP}-${ASB_ENV}
export ASB_CNAME=${ASB_FD_NAME}.azurefd.net
az network dns record-set cname create --name $ASB_CNAME_RECORD_SET_NAME \
                                       --resource-group $ASB_DNS_ZONE_RG \
                                       --zone-name $ASB_DNS_ZONE

az network dns record-set cname set-record --cname $ASB_CNAME \
                                           --record-set-name $ASB_CNAME_RECORD_SET_NAME \
                                           --resource-group $ASB_DNS_ZONE_RG \
                                           --zone-name $ASB_DNS_ZONE
```

## Step 3: Create WAF policy and associate it with Front Door

We can create a web access firewall (WAF) policy and assign it to our Front Door resource. Any of several managed rule sets can also be added to the WAF policy. In this example, the default rule set is applied. To see the available managed rule sets, use the Azure CLI command `az network front-door waf-policy managed-rule-definition list`. To see managed rule sets already added to the WAF policy, use the Azure CLI command `az network front-door waf-policy managed-rules list --policy-name [policyName] --resource-group [frontDoorResourceGroup]`.

```bash
# create WAF policy - Policy name rules: [a-z,A-Z]
export ASB_FD_WAF_POLICY_NAME=myFrontDoorWAFPolicy

az network front-door waf-policy create \
    --name $ASB_FD_WAF_POLICY_NAME \
    --resource-group $ASB_FD_RG_NAME  \
    --disabled false \
    --mode Detection

# add managed rule sets
az network front-door waf-policy managed-rules add \
    --policy-name $ASB_FD_WAF_POLICY_NAME \
    --resource-group $ASB_FD_RG_NAME \
    --type DefaultRuleSet \
    --version 1.0

# associate WAF policy with Front Door's default front endpoint
export ASB_FD_WAF_POLICY_ID=$(az network front-door waf-policy show -g $ASB_FD_RG_NAME --name $ASB_FD_WAF_POLICY_NAME --query id -o tsv)
az network front-door update \
    --name $ASB_FD_NAME \
    --resource-group $ASB_FD_RG_NAME \
    --set 'frontendEndpoints[0].webApplicationFirewallPolicyLink={"id":"'${ASB_FD_WAF_POLICY_ID}'"}'

# Note: If you are running these commands in Ubuntu, the command above should be updated to:
# az network front-door update \
#     --name $ASB_FD_NAME \
#     --resource-group $ASB_FD_RG_NAME \
#     --set frontendEndpoints[0].webApplicationFirewallPolicyLink='{"id":"'${ASB_FD_WAF_POLICY_ID}'"}'
```

## Step 4: Create front end endpoint

```bash
# add front end
export ASB_FD_FRONT_END_NAME=$ASB_CNAME_RECORD_SET_NAME
export ASB_FD_FRONT_END_HOST_NAME=${ASB_FD_FRONT_END_NAME}.cse.ms
az network front-door frontend-endpoint create --front-door-name $ASB_FD_NAME \
                                               --host-name $ASB_FD_FRONT_END_HOST_NAME \
                                               --name $ASB_FD_FRONT_END_NAME \
                                               --resource-group $ASB_FD_RG_NAME \
                                               --waf-policy $ASB_FD_WAF_POLICY_ID

# enable https
az network front-door frontend-endpoint enable-https --front-door-name $ASB_FD_NAME \
                                                     --name $ASB_FD_FRONT_END_NAME \
                                                     --resource-group $ASB_FD_RG_NAME
```

## Step 5: Create back end pool

Create the pool of backend endpoints and set up a health probe and weight-based load balancing for them.

```bash
# add backend pool
export ASB_FD_PROBE_NAME=probe-${ASB_FD_FRONT_END_NAME}
export ASB_FD_LB_NAME=lb-${ASB_FD_FRONT_END_NAME}
export ASB_FD_BACK_END_POOL_NAME=backend-${ASB_FD_FRONT_END_NAME}

# - health probe
az network front-door probe create  --resource-group $ASB_FD_RG_NAME \
                                    --front-door-name $ASB_FD_NAME \
                                    --name $ASB_FD_PROBE_NAME \
                                    --path "/healthz" \
                                    --interval 60 \
                                    --probeMethod GET \
                                    --protocol https \
                                    --enabled Enabled

# - load balancer
az network front-door load-balancing create --resource-group $ASB_FD_RG_NAME \
                                    --front-door-name $ASB_FD_NAME \
                                    --name $ASB_FD_LB_NAME \
                                    --sample-size 2 \
                                    --successful-samples-required 1 \
                                    --additional-latency 0

# - create backend pool with one endpoint
az network front-door backend-pool create   --resource-group $ASB_FD_RG_NAME \
                                            --front-door-name $ASB_FD_NAME \
                                            --name $ASB_FD_BACK_END_POOL_NAME \
                                            --probe $ASB_FD_PROBE_NAME \
                                            --load-balancing $ASB_FD_LB_NAME \
                                            --address $ASB_FD_BACKEND_ADDRESS \
                                            --http-port 80 \
                                            --https-port 443 \
                                            --priority 1 \
                                            --weight 50 \
                                            --disabled false

# - (OPTIONAL) add additional backend addresses to backend pool
# - Repeat with updated address for as many back ends as you need to connect to the new front end endpoint
export ASB_FD_LOCATION2=westus3
export ASB_FD_BACKEND_ADDRESS2=${ASB_FD_ROOT_NAME}-${ASB_NGSA_APP}-${ASB_FD_LOCATION2}-${ASB_ENV}.${ASB_DNS_ZONE}
az network front-door backend-pool backend add --resource-group $ASB_FD_RG_NAME \
                                            --front-door-name $ASB_FD_NAME \
                                            --pool-name $ASB_FD_BACK_END_POOL_NAME \
                                            --address $ASB_FD_BACKEND_ADDRESS2 \
                                            --http-port 80 \
                                            --https-port 443 \
                                            --priority 1 \
                                            --weight 50 \
                                            --disabled false
```

## Step 6: Create routing rule to link front end endpoint to backend pool

```bash
# add routing rule
export ASB_FD_BACK_ROUTING_RULE_NAME=routing-${ASB_FD_FRONT_END_NAME}
az network front-door routing-rule create   --resource-group $ASB_FD_RG_NAME \
                                            --front-door-name $ASB_FD_NAME \
                                            --name $ASB_FD_BACK_ROUTING_RULE_NAME \
                                            --frontend-endpoints $ASB_FD_FRONT_END_NAME \
                                            --backend-pool $ASB_FD_BACK_END_POOL_NAME \
                                            --route-type "Forward" \
                                            --accepted-protocols "Https" \
                                            --forwarding-protocol "HttpsOnly" \
                                            --disabled false

# add http to https routing rule
az network front-door routing-rule create   --resource-group $ASB_FD_RG_NAME \
                                            --front-door-name $ASB_FD_NAME \
                                            --name ${ASB_FD_BACK_ROUTING_RULE_NAME}-http-to-https \
                                            --frontend-endpoints $ASB_FD_FRONT_END_NAME \
                                            --route-type "Redirect" \
                                            --redirect-type "Found" \
                                            --redirect-protocol "HttpsOnly" \
                                            --disabled false
```

## Step 7: Delete default routing rules and backend pools

The Front Door resource requires at least one routing rule and one backend pool. A default instance of each is therefore created when the Front Door resource is created. These can be deleted after our custom routing rule(s) and backend pool(s) have been created.

```bash
# delete default backend pool and routing rule: 
az network front-door routing-rule delete --front-door-name $ASB_FD_NAME \
                                          --name DefaultRoutingRule \
                                          --resource-group $ASB_FD_RG_NAME 

az network front-door backend-pool delete --front-door-name $ASB_FD_NAME \
                                          --name DefaultBackendPool \
                                          --resource-group $ASB_FD_RG_NAME 
```
