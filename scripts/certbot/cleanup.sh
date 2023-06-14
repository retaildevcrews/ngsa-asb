#!/bin/bash

# https://eff-certbot.readthedocs.io/en/stable/using.html#pre-and-post-validation-hooks
# available variables provided by certbot:
# - CERTBOT_DOMAIN: The domain being authenticated
# - CERTBOT_VALIDATION: The validation string
# - CERTBOT_TOKEN: Resource name part of the HTTP-01 challenge (HTTP-01 only)
# - CERTBOT_REMAINING_CHALLENGES: Number of challenges remaining after the current challenge
# - CERTBOT_ALL_DOMAINS: A comma-separated list of all domains challenged for the current certificate
# - CERTBOT_AUTH_OUTPUT: Whatever the auth script wrote to stdout

# variables provided by user:
# AZURE_RESOURCE_GROUP: Resource group where the DNS Zone is located
# AZURE_DNS_ZONE: Name of the DNS Zone

# remove the DNS challenge txt record by value, keeping record set even if it is empty
az network dns record-set txt remove-record \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --zone-name "$AZURE_DNS_ZONE" \
  --record-set-name "_acme-challenge" \
  --value "$CERTBOT_VALIDATION" \
  --keep-empty-record-set
