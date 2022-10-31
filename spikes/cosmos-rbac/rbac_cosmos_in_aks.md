# Use Managed Identity to access CosmosDB using RBAC in NGSA AKS Secure Baseline

## Summary

In this spike, we show how to disable keys and connect the NGSA app to Cosmos DB in our NGSA-ASB AKS clusters using role-based access control (RBAC). This is important because currently Cosmos DB authentication keys are being stored as secrets in the AKS cluster. Implementation requires changes to two repositories:

- The [NGSA app](https://github.com/retaildevcrews/ngsa-app) code has to be updated so that the ***CosmosClient*** class uses RBAC
- The [NGSA-ASB](https://github.com/retaildevcrews/ngsa-asb) ***SecretProviderClass*** YAML needs to be updated to remove the variable "CosmosKey" from the SecretsProvider class, since this secret will no longer be stored in the cluster.

Additionally, role assignments need to be created to allow the managed identity to access the Cosmos DB.

## Implementation

### Prerequisites

- Add ***Azure.Identity*** nuget package to the NGSA-APP repo

### NGSA-APP Code Updates

In the file [src/DataAccessLayer/dalMain.cs](https://github.com/retaildevcrews/ngsa-app/blob/main/src/DataAccessLayer/dalMain.cs):

- Add `using Azure.Identity;`
- Remove all `if` statements that check for `CosmosKey`
- In [this section of dalMain.cs](https://github.com/retaildevcrews/ngsa-app/blob/main/src/DataAccessLayer/dalMain.cs#L103), replace the reference to CosmosKey with a DefaultAzureCredential instance, by replacing

```bash
CosmosClient c = new(cosmosServer, cosmosKey, cosmosDetails.CosmosClientOptions);
```

with

```bash
CosmosClient c = new CosmosClient(cosmosServer, new DefaultAzureCredential(), cosmosDetails.CosmosClientOptions);
```

In the file [src/Core/Secrets.cs](https://github.com/retaildevcrews/ngsa-app/blob/main/src/Core/Secrets.cs)

- Remove all references to the `CosmosKey` in the function [GetSecretsFromVolume](https://github.com/retaildevcrews/ngsa-app/blob/main/src/Core/Secrets.cs#L25)
- Remove any checks for the value of `CosmosKey` in the function [ValidateSecrets](https://github.com/retaildevcrews/ngsa-app/blob/main/src/Core/Secrets.cs#L54)

### NGSA-ASB YAML Updates

In the file [templates/ngsa/ngsa-pod-identity.yaml](https://github.com/retaildevcrews/ngsa-asb/blob/main/templates/ngsa/ngsa-pod-identity.yaml), remove the code block below from the [SecretProviderClass definition](https://github.com/retaildevcrews/ngsa-asb/blob/main/templates/ngsa/ngsa-pod-identity.yaml#L43)

```bash
        - |
          objectName: CosmosKey
          objectType: secret
```

### Role assignment definition and creation

- Create the role definition specification by pasting the code below into a text file. In this example we name the file ***definition.json***

```bash
{
    "RoleName": "Read Azure Cosmos DB Metadata",
    "Type": "CustomRole",
    "AssignableScopes": ["/"],
    "Permissions": [{
        "DataActions": [
            "Microsoft.DocumentDB/databaseAccounts/readMetadata"
        ]
    }]
}
```

- Run the commands below:

```bash
# create the role definition
az cosmosdb sql role definition create --resource-group ${ASB_COSMOS_RG_NAME} --account-name ${ASB_COSMOS_DB_NAME} --body @definition.json

# create the role assignment assigning read permission over the Cosmos DB account to the NGSA managed identity
# NGSA managed identity is already being managed by the AKS cluster
az cosmosdb sql role assignment create --resource-group ${ASB_COSMOS_RG_NAME} --account-name ${ASB_COSMOS_DB_NAME} --role-definition-name "Read Azure Cosmos DB Metadata" --principal-id ${ASB_NGSA_MI_PRINCIPAL_ID} --scope ${ASB_COSMOS_ID}

# assign read-write permissions over the Cosmos DB account to the managed identity
az cosmosdb sql role assignment create --resource-group ${ASB_COSMOS_RG_NAME} --account-name ${ASB_COSMOS_DB_NAME} --role-definition-id 00000000-0000-0000-0000-000000000002 --principal-id ${ASB_NGSA_MI_PRINCIPAL_ID} --scope ${ASB_COSMOS_ID}
```

## Resources

- [Instructions from learn.microsoft.com](https://learn.microsoft.com/en-us/azure/cosmos-db/managed-identity-based-authentication#grant-access-to-your-azure-cosmos-db-account)
- [Alternative approach demonstrated using PowerShell](https://joonasaijala.com/2021/07/01/how-to-using-managed-identities-to-access-cosmos-db-data-via-rbac-and-disabling-authentication-via-keys/)
