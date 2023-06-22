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
docker build -t cert-automation -f cert-automation/Dockerfile .

# run docker image locally
docker run -it --rm cert-automation sh

```
