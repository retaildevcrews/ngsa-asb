#!/bin/bash

# https://eff-certbot.readthedocs.io/en/stable/using.html#pre-and-post-validation-hooks
# available variables provided by certbot:
# - CERTBOT_DOMAIN: The domain being authenticated
# - CERTBOT_VALIDATION: The validation string
# - CERTBOT_TOKEN: Resource name part of the HTTP-01 challenge (HTTP-01 only)
# - CERTBOT_REMAINING_CHALLENGES: Number of challenges remaining after the current challenge
# - CERTBOT_ALL_DOMAINS: A comma-separated list of all domains challenged for the current certificate

# variables provided by user:
# AZURE_RESOURCE_GROUP: Resource group where the DNS Zone is located
# AZURE_DNS_ZONE: Name of the DNS Zone

# add a txt record for DNS challenge, creating a record set if it doesn't exist
az network dns record-set txt add-record \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --zone-name "$AZURE_DNS_ZONE" \
  --record-set-name "_acme-challenge" \
  --value "$CERTBOT_VALIDATION"

# wait some time for the TXT record to propagate
sleep 25
