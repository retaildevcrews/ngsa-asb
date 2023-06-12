# Renew SSL Certificates

The following instructions will guide you on how to renew  the existing ssl certificates for the ngsa-asb setup.

## Create Certificate bundle

Before getting started, ensure that the ssl issuer has provided you with following:

- star certificate (e.g. star_austinrdc_dev.crt)
- My_CA_Bundle.crt
- key file

Next, we are going to combine the star certificate with My_CA_Bundle.crt to create a new certificate that will be installed in our infrastructure.

``` bash
cat star_austinrdc_dev.crt My_CA_Bundle.crt  > ngsa_bundle.crt
```

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

## WIP lets encrypt notes

```bash

# install certbot
sudo apt-get install certbot

# let's encrypt servers
# staging
export LETS_ENCRYPT_STAGING_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory
# production
# careful to not hit the rate limits, test in staging first
# more info about rate limits can be found here: https://letsencrypt.org/docs/rate-limits/
export LETS_ENCRYPT_PRODUCTION_SERVER=https://acme-v02.api.letsencrypt.org/directory

# let's encrypt account email for important communication
export ACCOUNT_EMAIL=<email address here>

# domain for which the certificate is being generated
export DOMAIN="*.austinrdc.dev"

# create a directory that is writable by the current user
# allows for running certbot without sudo
export CERTBOT_WORKING_DIR="certbot"
mkdir -p ~/"$CERTBOT_WORKING_DIR"

# generate a certificate using dns challenge, without attemptingting to install them
# use hooks mechanism to automate the dns challenge and cleanup
# more information about hooks can be found here: https://certbot.eff.org/docs/using.html#pre-and-post-validation-hooks

# login and set target subscription
az login

az account set -s <subscription name or id>

az account show -o table

# variables used by auth and cleanup hooks to communicate with azure dns
export AZURE_RESOURCE_GROUP="dns-rg"
export AZURE_DNS_ZONE="austinrdc.dev"

# run certbot, using hooks to manage dns challenge and cleanup
certbot certonly \
  --manual \
  --preferred-challenges dns \
  --email "$ACCOUNT_EMAIL" \
  --server "$LETS_ENCRYPT_STAGING_SERVER" \
  --domain "$DOMAIN" \
  --logs-dir ~/"$CERTBOT_WORKING_DIR" \
  --config-dir ~/"$CERTBOT_WORKING_DIR" \
  --work-dir ~/"$CERTBOT_WORKING_DIR" \
  --manual-auth-hook "./scripts/certbot/authenticator.sh" \
  --manual-cleanup-hook "./scripts/certbot/cleanup.sh" \
  --keep-until-expiring \
  --agree-tos \
  --dry-run

# view certificate files
ls -la ~/${CERTBOT_WORKING_DIR}/live/austinrdc.dev

# TODO: next steps
# create a pfx formated file?
# upload certificate to key vault
# restart app gateway?
# restart istio ingress?
# delete certs from local machine?

```
