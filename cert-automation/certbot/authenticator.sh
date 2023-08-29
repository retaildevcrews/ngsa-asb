#!/bin/bash

# available variables provided by certbot:
# https://eff-certbot.readthedocs.io/en/stable/using.html#pre-and-post-validation-hooks
# CERTBOT_VALIDATION: The validation string

# variables provided by user:
# AZURE_DNS_RESOURCE_GROUP: Resource group where the DNS Zone is located
# AZURE_DNS_ZONE: Name of the DNS Zone

# add a txt record for DNS challenge, creating a record set if it doesn't exist
az network dns record-set txt add-record \
  --resource-group "$AZURE_DNS_RESOURCE_GROUP" \
  --zone-name "$AZURE_DNS_ZONE" \
  --record-set-name "_acme-challenge" \
  --value "$CERTBOT_VALIDATION" \
  --query "id" \
  -o tsv

# wait some time for the TXT record to propagate
sleep 25
