#!/bin/bash

# TODO: check if required environment variables are set and show error message if not
# AZURE_DNS_ZONE
# AZURE_RESOURCE_GROUP
# CERTBOT_ACCOUNT_EMAIL
# CERTBOT_CERTNAME
# CERTBOT_DOMAIN
# KV_FULL_CHAIN_SECRET_NAME
# KV_NAME
# KV_PFX_SECRET_NAME
# KV_PRIVATE_KEY_SECRET_NAME

# Let's Encrypt environment, staging or production, defaults to staging
LETS_ENCRYPT_ENVIRONMENT=${LETS_ENCRYPT_ENVIRONMENT:-staging}
# Set the number of days before the certificate expires to renew it, defaults to 30
NUM_DAYS_TO_RENEW=${NUM_DAYS_TO_RENEW:-30}

main() {
  check_certificate_expiration
  generate_certificate && upload_to_key_vault
}

# exit early if certificate from provided key vault is not close to expiration
check_certificate_expiration() {
  echo "Checking certificate expiration..."

  local expiration_date=""
  local certificate_value=$(az keyvault secret show \
    --vault-name "$KV_NAME" \
    --name "$KV_FULL_CHAIN_SECRET_NAME" \
    --query value \
    --output tsv)

  # stop validation early if the certificate is not found or empty
  if [ -z "$certificate_value" ]; then
    echo "Certificate '$KV_FULL_CHAIN_SECRET_NAME' not found or empty in key vault '$KV_NAME'."
    return 0
  fi

  # get expiration date
  expiration_date=$(echo "$certificate_value" | openssl x509 -noout -enddate | cut -d'=' -f2)

  # check that the date format is valid
  if date -d "$expiration_date"; then
    echo "Valid SSL certificate expiration date: $expiration_date"
  else
    echo "Invalid SSL certificate expiration date: $expiration_date"
    exit 1
  fi

  local expiration_date_seconds=$(date -d "$expiration_date" +%s)
  local today_in_seconds=$(date +%s)
  local num_days_remaining=$(( (expiration_date_seconds - today_in_seconds) / 86400 ))

  echo "Number of days until certificate expires: $num_days_remaining"

  # exit early if the certificate is not close to expiring
  if [ "$num_days_remaining" -gt "$NUM_DAYS_TO_RENEW" ]; then
    echo "Certificate is not close to expiring, exiting early."
    exit 0
  else
    echo "Certificate is close to expiring."
  fi
}

generate_certificate() {
  echo "Generating certificate..."

  # Let's Encrypt staging server
  local lets_encrypt_staging_server=https://acme-staging-v02.api.letsencrypt.org/directory
  # Let's Encrypt production server
  local lets_encrypt_production_server=https://acme-v02.api.letsencrypt.org/directory

  # set the let's encrypt server based on the environment
  local lets_encrypt_server=""
  if [ "$LETS_ENCRYPT_ENVIRONMENT" == "production" ]; then
    lets_encrypt_server="$lets_encrypt_production_server"
  else
    lets_encrypt_server="$lets_encrypt_staging_server"
  fi

  certbot certonly \
    --manual \
    --preferred-challenges dns \
    --email "$CERTBOT_ACCOUNT_EMAIL" \
    --server "$lets_encrypt_server" \
    --cert-name "$CERTBOT_CERTNAME" \
    --domain "$CERTBOT_DOMAIN" \
    --logs-dir ~/certbot-files \
    --config-dir ~/certbot-files \
    --work-dir ~/certbot-files \
    --manual-auth-hook "./cert-automation/certbot/authenticator.sh" \
    --manual-cleanup-hook "./cert-automation/certbot/cleanup.sh" \
    --keep-until-expiring \
    --agree-tos \
    --non-interactive \
    --no-eff-email
}

upload_to_key_vault() {
  echo "Uploading to key vault..."

  local full_chain_location=~/"certbot-files/live/${CERTBOT_CERTNAME}/fullchain.pem"
  local key_location=~/"certbot-files/live/${CERTBOT_CERTNAME}/privkey.pem"

  # generate pfx file
  openssl pkcs12 \
    -export \
    -inkey $key_location \
    -in $full_chain_location \
    -out certificate.pfx \
    -passout pass:

  local pfx_base64=$(cat certificate.pfx | base64)

  az keyvault secret set --vault-name $KV_NAME --name "$KV_PFX_SECRET_NAME" --value "$pfx_base64" --query id -o tsv
  az keyvault secret set --vault-name $KV_NAME --name "$KV_FULL_CHAIN_SECRET_NAME" --file "$full_chain_location" --query id -o tsv
  az keyvault secret set --vault-name $KV_NAME --name "$KV_PRIVATE_KEY_SECRET_NAME" --file "$key_location" --query id -o tsv
}

main
