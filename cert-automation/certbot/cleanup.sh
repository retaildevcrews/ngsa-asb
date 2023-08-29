#!/bin/bash

# available variables provided by certbot:
# https://eff-certbot.readthedocs.io/en/stable/using.html#pre-and-post-validation-hooks
# CERTBOT_VALIDATION: The validation string

# variables provided by user:
# AZURE_DNS_RESOURCE_GROUP: Resource group where the DNS Zone is located
# AZURE_DNS_ZONE: Name of the DNS Zone

# remove the DNS challenge txt record by value, keeping record set even if it is empty
az network dns record-set txt remove-record \
  --resource-group "$AZURE_DNS_RESOURCE_GROUP" \
  --zone-name "$AZURE_DNS_ZONE" \
  --record-set-name "_acme-challenge" \
  --value "$CERTBOT_VALIDATION" \
  --keep-empty-record-set \
  --query "id" \
  -o tsv
