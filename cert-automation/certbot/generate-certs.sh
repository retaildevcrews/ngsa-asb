#!/bin/bash

# TODO: read certificate from key vault and get expiration date
EXPIRATION_DATE=""

# view the expiration date
echo "EXPIRATION_DATE: $EXPIRATION_DATE"

# check that the date format is valid
if date -d "$EXPIRATION_DATE"; then
  echo "Valid SSL certificate expiration date: $EXPIRATION_DATE"
else
  echo "Invalid SSL certificate expiration date: $EXPIRATION_DATE"
  exit 1
fi

# expiration date in seconds
EXP=$(date -d "$EXPIRATION_DATE" +%s)

# today's date in seconds
TODAY=$(date +%s)

# calculate the number of days remaining
DAYS_REMAINING=$(( (EXP - TODAY) / 86400 ))

echo "DAYS_REMAINING: $DAYS_REMAINING"

# TODO: exit early if the certificate is not close to expiring
# TODO: make amount of days for "close to expiring" configurable

# Let's Encrypt staging server
LETS_ENCRYPT_STAGING_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory

# Let's Encrypt production server
LETS_ENCRYPT_PRODUCTION_SERVER=https://acme-v02.api.letsencrypt.org/directory

# TODO: make configurable
# Domain for which the certificate is being generated
DOMAIN="*.austinrdc.dev"

# TODO: make configurable and set outside of script
# Set Azure DNS variables for use in domain validation via DNS challenge
# export AZURE_RESOURCE_GROUP="dns-rg"
# export AZURE_DNS_ZONE="austinrdc.dev"

# TODO: make configurable
# Let's Encrypt account email for important communication like upcoming certificate expiration
ACCOUNT_EMAIL=<email address here>

# TODO: make which server, stage or prod, to use configurable
# Run certbot, using hooks to manage dns challenge and cleanup
certbot certonly \
  --manual \
  --preferred-challenges dns \
  --email "$ACCOUNT_EMAIL" \
  --server "$LETS_ENCRYPT_STAGING_SERVER" \
  --domain "$DOMAIN" \
  --logs-dir ~/certbot-files \
  --config-dir ~/certbot-files \
  --work-dir ~/certbot-files \
  --manual-auth-hook "./cert-automation/certbot/authenticator.sh" \
  --manual-cleanup-hook "./cert-automation/certbot/cleanup.sh" \
  --keep-until-expiring \
  --agree-tos \
  --non-interactive \
  --no-eff-email

# TODO: generate file locations from $DOMAIN
FULL_CHAIN_LOCATION=~/certbot-files/live/austinrdc.dev/fullchain.pem
KEY_LOCATION=~/certbot-files/live/austinrdc.dev/privkey.pem

# generate pfx file
openssl pkcs12 \
  -export \
  -inkey $KEY_LOCATION \
  -in $FULL_CHAIN_LOCATION \
  -out certificate.pfx \
  -passout pass:

# TODO: upload full chain, private key, and pfx to key vault as secrets
# TODO: make key vault secret names configurable
