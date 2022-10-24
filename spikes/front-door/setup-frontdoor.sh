#!/bin/bash


# create resource group for front door
export ASB_ENV=dev
export ASB_FD_ROOT_NAME=fdauto-ngsa
export ASB_FD_NAME=${ASB_FD_ROOT_NAME}-${ASB_ENV}
export ASB_FD_RG_NAME=rg-front-door-${ASB_FD_NAME}
export ASB_FD_LOCATION=centralus

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

# create CNAME record aliased to Azure front door URL
export ASB_CNAME_RECORD_SET_NAME=${ASB_FD_ROOT_NAME}-${ASB_NGSA_APP}-${ASB_ENV}
export ASB_CNAME=${ASB_FD_NAME}.azurefd.net
az network dns record-set cname create --name $ASB_CNAME_RECORD_SET_NAME \
                                       --resource-group $ASB_DNS_ZONE_RG \
                                       --zone-name $ASB_DNS_ZONE

az network dns record-set cname set-record --cname $ASB_CNAME \
                                           --record-set-name $ASB_CNAME_RECORD_SET_NAME \
                                           --resource-group $ASB_DNS_ZONE_RG \
                                           --zone-name $ASB_DNS_ZONE

# create WAF policy
export ASB_FD_WAF_POLICY_NAME=fdautoFrontDoorWAFPolicy
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
    --set frontendEndpoints[0].webApplicationFirewallPolicyLink='{"id":"'${ASB_FD_WAF_POLICY_ID}'"}'


# add front end
export ASB_FD_FRONT_END_NAME=$ASB_CNAME_RECORD_SET_NAME
export ASB_FD_FRONT_END_HOST_NAME=${ASB_FD_FRONT_END_NAME}.cse.ms
az network front-door frontend-endpoint create --front-door-name $ASB_FD_NAME \
                                               --host-name $ASB_FD_FRONT_END_HOST_NAME \
                                               --name $ASB_FD_FRONT_END_NAME \
                                               --resource-group $ASB_FD_RG_NAME \
                                               --waf-policy $ASB_FD_WAF_POLICY_ID

az network front-door frontend-endpoint enable-https --front-door-name $ASB_FD_NAME \
                                                     --name $ASB_FD_FRONT_END_NAME \
                                                     --resource-group $ASB_FD_RG_NAME

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

# - add additional backends to backend pool
export ASB_FD_LOCATION2=westus2
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


# delete default backend pool and routing rule: AT END
az network front-door routing-rule delete --front-door-name $ASB_FD_NAME \
                                          --name DefaultRoutingRule \
                                          --resource-group $ASB_FD_RG_NAME 

az network front-door backend-pool delete --front-door-name $ASB_FD_NAME \
                                          --name DefaultBackendPool \
                                          --resource-group $ASB_FD_RG_NAME 
