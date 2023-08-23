#!/bin/bash

# Let's Encrypt environment, staging or production, defaults to staging
LETS_ENCRYPT_ENVIRONMENT=${LETS_ENCRYPT_ENVIRONMENT:-staging}
# Set the number of days before the certificate expires to renew it, defaults to 30
NUM_DAYS_TO_RENEW=${NUM_DAYS_TO_RENEW:-30}

expiration_date=""
main() {
  check_certificate_expiration
  generate_certificate && upload_to_key_vault
}

# set expiration date variable from certificate in key vault
set_expiration_date() {
  echo "Getting expiration date..."

  local certificate_value=$(az keyvault secret show \
    --vault-name "$KV_NAME" \
    --name "$KV_FULL_CHAIN_SECRET_NAME" \
    --query value \
    --output tsv)

  if [ -n "$certificate_value" ]; then
    # get expiration date from certificate
    expiration_date=$(echo "$certificate_value" | openssl x509 -noout -enddate | cut -d'=' -f2)
  else
    # default expiration date to today if missing, resulting in a new certificate being generated
    echo "Certificate '$KV_FULL_CHAIN_SECRET_NAME' not found or empty in key vault '$KV_NAME'."
    echo "Default expiration date to today."
    expiration_date=$(date)
  fi

  # double check that the date format can be parsed
  if ! date -d "$expiration_date"; then
    echo "Invalid SSL certificate expiration date: $expiration_date"
    exit 1
  fi
}

# check if the expiration date is close to the configured renewal threshold
check_certificate_expiration() {
  echo "Checking certificate expiration date..."

  set_expiration_date
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

# generate staging or production certificate with certbot
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

  # Run certbot, using hooks to manage dns challenge and cleanup
  # More information on the flags can be found here, https://eff-certbot.readthedocs.io/en/stable/using.html#certbot-command-line-options
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

# upload certificate information to specified key vault
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
