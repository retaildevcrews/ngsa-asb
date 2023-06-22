# TODO - Rough notes for lets encrypt automation

TODO: context behind setup.

- need central location to manage certificates and automation
  - multiple clusters and app gateways need access to same wildcard cert
- didn't use something like cert-manager because it is tied to a specific cluster
  - running in multiple clusters increases likelihood of hitting lets encrypt rate limits
  - clusters are shutdown and restarted daily, so running in only one cluster can cause timing issues
  - certificates are generated in the cluster, but external resources need access
- certbot is recommended client by lets encrypt

TODO: overall setup:

- docker image with az cli and certbot

- managed identity for automation
- used for both azure function and aci

- needs permissions to create aci
- needs permissions to read and set keys in key vault
- needs permissions to create and delete TXT records in dns zone

- azure function with timer trigger creates azure container instance
- aci runs docker image
- docker image checks key vault for certificate expiration
- if certificate is expired, run certbot to renew certificate
- generate pfx file
- save pfx, cert, and key to key vault

commands

```bash

# build docker image in cert-automation directory from root directory
docker build -t ghcr.io/retaildevcrews/cert-automation -f cert-automation/Dockerfile .

# run docker image locally
docker run -it --rm ghcr.io/retaildevcrews/cert-automation sh

# create a PAT and login
# https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-with-a-personal-access-token-classic
#
# create token with package access only by going here https://github.com/settings/tokens/new?scopes=write:packages
# export CR_PAT=YOUR_TOKEN
# echo $CR_PAT | docker login ghcr.io -u USERNAME --password-stdin

# push image to ghcr
docker push ghcr.io/retaildevcrews/cert-automation

```

dev/test locally

```bash

az login
az account set -s <subscription name or id>
az account show

# test script locally
# these can be set in ACI as env vars
export AZURE_DNS_ZONE="austinrdc.dev"
export AZURE_RESOURCE_GROUP="dns-rg"
export CERTBOT_ACCOUNT_EMAIL="<email address here>"
export CERTBOT_CERTNAME="austinrdc-dev"
export CERTBOT_DOMAIN="*.austinrdc.dev"
export KV_FULL_CHAIN_SECRET_NAME="ak-automation-test-tls-crt"
export KV_NAME="kv-aks-jxdthrti3j3qu"
export KV_PFX_SECRET_NAME="ak-automation-test-tls-pfx"
export KV_PRIVATE_KEY_SECRET_NAME="ak-automation-test-tls-key"
# export LETS_ENCRYPT_ENVIRONMENT="<staging or production. defaults to staging if not set>"

# create directory for certbot
# already exists in docker image
mkdir -p ~/certbot-files

# run script
./cert-automation/certbot/generate-certs.sh

```
