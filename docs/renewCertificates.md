# Renew SSL Certificates

The following instructions will guide you on how to renew  the existing ssl certificates for the ngsa-asb setup.

## Provision certificates

### Check expiration date

You can check the expiration date of the deployed certificate from the website. This can also be used in automation to check when to renew a certificate, in order to avoid downtime or hitting rate limits.

```bash

# get the expiration date of the certificate directly from the site
EXPIRATION_DATE=$(echo | \
  openssl s_client -connect grafana-eastus-dev.austinrdc.dev:443 -servername austinrdc.dev 2> /dev/null | \
  openssl x509 -noout -enddate | \
  cut -d'=' -f2)

# view the expiration date
echo $EXPIRATION_DATE

# check that the date format is valid
# on mac, use `date -j -f "%b %d %T %Y %Z" "$EXPIRATION_DATE"`
if date -d "$EXPIRATION_DATE"; then
  echo "Valid SSL certificate expiration date: $EXPIRATION_DATE"
else
  echo "Invalid SSL certificate expiration date: $EXPIRATION_DATE"
  # exit early in automation
  # exit 1
fi

```

Then calculate how many days are left until the certificate expires.

```bash

# expiration date in seconds
# on mac, use `date -j -f "%b %d %T %Y %Z" "$EXPIRATION_DATE" +%s`
EXP=$(date -d "$EXPIRATION_DATE" +%s)

# today's date in seconds
TODAY=$(date +%s)

# calculate the number of days remaining
DAYS_REMAINING=$(( (EXP - TODAY) / 86400 ))

echo $DAYS_REMAINING

```

### Option 1 - Existing certificates

This option assumes you have access to an existing certificate or are purchasing one.

Before getting started, ensure that the ssl issuer has provided you with following:

- star certificate (e.g. star_austinrdc_dev.crt)
- My_CA_Bundle.crt
- key file

Next, we are going to combine the star certificate with My_CA_Bundle.crt to create a new certificate that will be installed in our infrastructure.

``` bash
cat star_austinrdc_dev.crt My_CA_Bundle.crt  > ngsa_bundle.crt
```

### Option 2 - Use Lets Encrypt

This option documents how to use [Let's Encrypt](https://letsencrypt.org/) and [certbot](https://certbot.eff.org/docs/) to provision certificates. While this doccumentation is specific to certbot, [other clients](https://letsencrypt.org/docs/client-options/) are available.

Before getting started, ensure you have access to create TXT records for the domain you are requesting a certificate for.

#### Initial setup

```bash

# Install certbot
sudo apt-get install certbot=1.12.0-2

# Login to Azure
az login

# Set the target subscription
az account set -s <subscription name or id>

# Verify the target subscription
az account show -o table

```

#### Set environment variables

```bash

# Let's Encrypt staging server
# Use this server to test first before moving to production
export LETS_ENCRYPT_STAGING_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory

# Let's Encrypt production server
# Careful to not hit the rate limits by testing in staging first.
# More info about rate limits can be found here: https://letsencrypt.org/docs/rate-limits/
export LETS_ENCRYPT_PRODUCTION_SERVER=https://acme-v02.api.letsencrypt.org/directory

# Domain for which the certificate is being generated
export DOMAIN="*.austinrdc.dev"

# Directory where certbot will store files
export CERTBOT_WORKING_DIR="certbot"

# Set Azure DNS variables for use in domain validation via DNS challenge
export AZURE_DNS_RESOURCE_GROUP="dns-rg"
export AZURE_DNS_ZONE="austinrdc.dev"

```

Set an email address for the Let's Encrypt account.

```bash

# Let's Encrypt account email for important communication like upcoming certificate expiration
export ACCOUNT_EMAIL=<email address here>

```

#### Get test certificate from staging environment

> **Note**
> When using Let's Encrypt, it is recommended to test first using the staging environment before moving to production. This will allow you to test the process without hitting the [rate limits](https://letsencrypt.org/docs/rate-limits/).

Certbot will use the `./cert-automation/certbot/authenticator.sh` script to generate the TXT record for domain validation. Then `./cert-automation/certbot/cleanup.sh` will be used to remove the TXT record after validation is complete.

```bash

# Create a directory that is writable by the current user
# This allows you to run certbot without sudo if desired
mkdir -p ~/"$CERTBOT_WORKING_DIR"

# Run certbot, using hooks to manage dns challenge and cleanup
# More information on the flags can be found here, https://eff-certbot.readthedocs.io/en/stable/using.html#certbot-command-line-options
certbot certonly \
  --manual \
  --preferred-challenges dns \
  --email "$ACCOUNT_EMAIL" \
  --server "$LETS_ENCRYPT_STAGING_SERVER" \
  --domain "$DOMAIN" \
  --logs-dir ~/"$CERTBOT_WORKING_DIR" \
  --config-dir ~/"$CERTBOT_WORKING_DIR" \
  --work-dir ~/"$CERTBOT_WORKING_DIR" \
  --manual-auth-hook "./cert-automation/certbot/authenticator.sh" \
  --manual-cleanup-hook "./cert-automation/certbot/cleanup.sh" \
  --keep-until-expiring \
  --agree-tos \
  --non-interactive \
  --no-eff-email \
  --dry-run

```

This will generate 4 files in the `$CERTBOT_WORKING_DIR` directory.

Example:

- ~/certbot/live/austinrdc.dev/cert.pem
- ~/certbot/live/austinrdc.dev/chain.pem
- ~/certbot/live/austinrdc.dev/fullchain.pem
- ~/certbot/live/austinrdc.dev/privkey.pem

#### Get certificate from production environment

When testing is complete, run the certbot command again with the following changes:

- Change the `--server` flag to use the Let's Encrypt production server, `$LETS_ENCRYPT_PRODUCTION_SERVER`
- Remove the `--dry-run` flag

## Generate PFX Certificate to be used by the Application Gateways

The Application Gateways require an additional PFX file, this can be created using `openssl` cli tool and exporting it to KeyVault.

``` bash
openssl pkcs12 -export -inkey _.austinrdc.dev.key -in ngsa_bundle.crt -out certificate.pfx

SecretValue=$(cat certificate.pfx | base64)

export KEYVAULT_NAME=<keyvault-name>

export KEYVAULT_SECRET_ID=$(az keyvault secret set --vault-name $KEYVAULT_NAME --name sslcert --value ${SecretValue} --query id -o tsv)

export APP_GATEWAY_RG_NAME=<app-gateway-rg-name>
export APP_GATEWAY_NAME=<app-gateway-name>

az network application-gateway ssl-cert create -g $APP_GATEWAY_RG_NAME --gateway-name $APP_GATEWAY_NAME -n $APP_GATEWAY_NAME-ssl-certificate-austinrdc --key-vault-secret-id $KEYVAULT_SECRET_ID

# Note: you may need to check the app gateway listeners on the portal to ensure the change was reflected.
```

## Renew Certificates for Istio

Next steps involve uploading the certificates to keyvault so that they can be used by Istio (you will need to re-create the istio pods after this step)

``` bash
az keyvault secret set --vault-name $KEYVAULT_NAME --name "appgw-ingress-internal-aks-ingress-tls" --file "ngsa_bundle.crt"

az keyvault secret set --vault-name $KEYVAULT_NAME --name "appgw-ingress-internal-aks-ingress-key" --file "_.austinrdc.dev.key"
```

## Renew Codespaces secrets

The final step is to update the codespaces secrets with the contents of its respective file.

**Note** these must be encoded in base 64.

```text
APP_GW_CERT_CSMS = certificate.pfx
INGRESS_CERT_CSMS = ngsa_bundle.crt
INGRESS_KEY_CSMS = austinrdc.dev.key
```
