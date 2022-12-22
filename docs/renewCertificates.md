# Renew SSL Certificates

The following instructions will guide you on how to renew  the existing ssl certificates for the ngsa-asb setup.

## Create Cerificate bundle
	
	Before getting started, ensure that the ssl certificate issuer provided you with the star certificate (star_austinrdc_dev.crt), My_CA_Bundle.crt and the keey file. Next, we are going to combine the star certificate with My_CA_Bundle.crt to create the certificate that will be deployed.

	``` bash
		cat star_austinrdc_dev.crt My_CA_Bundle.crt  > newbundle.crt
	```



## Generate PFX Certificate to be used by Application Gateway

	openssl pkcs12 -export -inkey _.austinrdc.dev.key -in CER\ -\ CRT\ Files/newbundle.crt -out certificate.pfx

	SecretValue=$(cat certificate.pfx | base64)

	az keyvault secret set --vault-name kv-aks-jxdthrti3j3qu --name sslcertAustinRdc --value ${SecretValue}

	az network application-gateway ssl-cert create -g rg-wcnp-dev --gateway-name apw-aks-jxdthrti3j3qu-eastus -n apw-aks-jxdthrti3j3qu-eastus-ssl-certificate-austinrdc --key-vault-secret-id https://kv-aks-jxdthrti3j3qu.vault.azure.net/secrets/sslcertAustinRdc/cc0c81ff5fc94ef0aa949994aa7a57cb


## Certificates for Istio
	az keyvault secret set --vault-name "kv-aks-jxdthrti3j3qu" --name "test-appgw-ingress-internal-aks-ingress-tls" --file "newbundle.crt"

	az keyvault secret set --vault-name "kv-aks-jxdthrti3j3qu" --name "test-appgw-ingress-internal-aks-ingress-key" --file "_.austinrdc.dev.key"
