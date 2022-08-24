# Web Application Firewall (WAF) config

## WAF Policy in place

If you encounter the following error when [creating app gateway resources](../README.md#create-app-gateway-resources) you will need to manually disable the AppGateway default WAF configuration.

```bash
(ApplicationGatewayWafConfigurationCannotBeChangedWithWafPolicy) WebApplicationFirewallConfiguration cannot be changed when there is a WAF Policy /subscriptions/<subsriptionid>/resourceGroups/<resource-group>/providers/Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies/<waf-policy> associated with it.
```

### Check WAF config status

```bash
# Run the waf-config show command to check the current WAF config status
az network application-gateway waf-config show -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME

e.g.
{
  "disabledRuleGroups": [
    {
        "ruleGroupName": "REQUEST-942-APPLICATION-ATTACK-SQLI",
        "rules": [
            942150,
            942410
        ]
    }
  ],
  "enabled": true,
  "exclusions": null,
  "fileUploadLimitInMb": 100,
  "firewallMode": "Detection",
  "maxRequestBodySize": null,
  "maxRequestBodySizeInKb": 128,
  "requestBodyCheck": true,
  "ruleSetType": "OWASP",
  "ruleSetVersion": "3.0"
}

```
if attribute "enabled" is set to `true` you will need to [disable waf config](#disable-waf-config)

### Disable WAF config

```bash
# Run the waf-config set command to disable default waf-config
az network application-gateway waf-config set --resource-group $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME --enabled false --rule-set-version 3.0
```

### Validate

```bash

# Run the waf-config show command again to verify that config is now disabled
az network application-gateway waf-config show -g $ASB_RG_CORE --gateway-name $ASB_APP_GW_NAME

e.g
{
  "disabledRuleGroups": [],
  "enabled": false,
  "exclusions": null,
  "fileUploadLimitInMb": 100,
  "firewallMode": "Detection",
  "maxRequestBodySize": null,
  "maxRequestBodySizeInKb": 128,
  "requestBodyCheck": true,
  "ruleSetType": "OWASP",
  "ruleSetVersion": "3.0"
}

```

### Reference

- [az network application-gateway waf-config](https://docs.microsoft.com/en-us/cli/azure/network/application-gateway/waf-config)
- [Azure Web Application Firewall: WAF config versus WAF policy](https://techcommunity.microsoft.com/t5/azure-network-security-blog/azure-web-application-firewall-waf-config-versus-waf-policy/ba-p/2270525)
