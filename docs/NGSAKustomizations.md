# NGSA App Kustomizations

## Kustomize Layers for NGSA

Kubernetes Kustomize allows for specialization of Kubernetes files and Helm charts by applying overlays on top of base versions of files. This provides ability to chain bulding out configurations in a layered approach reducing the need for duplication of our infrastructure description code.

For NGSA ASB platform build out, the process involves 3 layers:

- Base - layer that contains infrastructure description shared between all clusters
- Environment - layer that contains infrastructure description shared between all clusters within a deployment environment (ie. Development or Preproduction)
- Cluster Specific - layer that contains environment description that is specific to an individual cluster

```mermaid

flowchart TD
    subgraph Base
        direction LR
        bootstrap-base
        apps-base
    end
    subgraph environment-dev[Dev Environment]
        direction LR
        bootstrap-dev
        apps-dev
    end
    subgraph environment-pre[Preprod Environment]
        direction LR
        bootstrap-pre
        apps-pre
    end
    subgraph dev-ngsa-asb-eastus[Cluster dev-ngsa-asb-eastus]
        direction LR
        apps-deveast
    end     
    subgraph dev-ngsa-asb-westus3[Cluster dev-ngsa-asb-westus3]
        direction LR
        apps-deveast
    end
    subgraph pre-ngsa-asb-northcentralus[Cluster pre-ngsa-asb-northcentralus]
        direction LR
        apps-prenorthcentral
    end
    subgraph pre-ngsa-asb-eastus[Cluster pre-ngsa-asb-eastus]
        direction LR
        apps-preeast
    end
    subgraph pre-ngsa-asb-westus3[Cluster pre-ngsa-asb-westus3]
        direction LR
        apps-prewest3
    end
    dev-ngsa-asb-eastus --> environment-dev
    dev-ngsa-asb-westus3 --> environment-dev
    pre-ngsa-asb-eastus --> environment-pre
    pre-ngsa-asb-westus3 --> environment-pre
    pre-ngsa-asb-northcentralus --> environment-pre
    environment-dev --> Base
    environment-pre --> Base 
```
