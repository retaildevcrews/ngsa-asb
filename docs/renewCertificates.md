# Renew SSL Certificates

The following instructions will guide you on how to renew  the existing ssl certificates for the ngsa-asb setup.

## Provision certificates

### Option 1 - Use Lets Encrypt

This option documents how to use [Let's Encrypt](https://letsencrypt.org/) and [certbot](https://certbot.eff.org/docs/) to provision certificates. While this doccumentation is specific to certbot, [other clients](https://letsencrypt.org/docs/client-options/) are available.

Before getting started, ensure you have access to create TXT records for the domain you are requesting a certificate for. When ready, follow the documentation [here](/cert-automation/README.md) to use a helper script to provision the certificates.

### Option 2 - Existing certificates

This option assumes you have access to an existing certificate or are purchasing one.

Before getting started, ensure that the ssl issuer has provided you with following:

- star certificate (e.g. star_austinrdc_dev.crt)
- My_CA_Bundle.crt
- key file

Next, we are going to combine the star certificate with My_CA_Bundle.crt to create a new certificate that will be installed in our infrastructure.

``` bash
cat star_austinrdc_dev.crt My_CA_Bundle.crt  > ngsa_bundle.crt
```

#### Generate PFX Certificate to be used by the Application Gateways

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

#### Renew Certificates for Istio

Next steps involve uploading the certificates to keyvault so that they can be used by Istio (you will need to re-create the istio pods after this step)

``` bash
az keyvault secret set --vault-name $KEYVAULT_NAME --name "appgw-ingress-internal-aks-ingress-tls" --file "ngsa_bundle.crt"

az keyvault secret set --vault-name $KEYVAULT_NAME --name "appgw-ingress-internal-aks-ingress-key" --file "_.austinrdc.dev.key"
```
