# Flux directory structure for NGSA ASB Clusters (dev and preprod)

To make use of Flux's features we've adopted the following dir structure based on our original ASB repo structure.

**Note:** _A Flux Kustomization CRD will always look for a `kustomization.yaml` file in a specified path. Otherwise it will generate one from the content of the directory. See [Kustomization doc (`path`description)](https://fluxcd.io/flux/components/kustomize/api/#kustomize.toolkit.fluxcd.io/v1beta2.KustomizationSpec)_

## `flux-init` Directory

```bash
flux-init
├── init-dev
│   ├── gotk-components-dev.yaml
│   ├── gotk-repo.yaml
│   ├── gotk-sync.yaml # Flux kustomzn: Kustomization for flux-init/init-dev
│   ╰── *(1)kustomization.yaml # k8s kustmzn: 1. <kubectl apply -k> applies all yaml files above
╰── init-pre
    ├── gotk-components-pre.yaml
    ├── gotk-repo.yaml
    ├── gotk-sync.yaml # Applies yamls in flux-init/init-pre for reconciliation
    ╰── *(1)kustomization.yaml # k8s kustmzn: 1. <kubectl apply -k> applies all yaml files above
```

## `deploy/bootstrap` Directory

```bash
deploy
├── base/bootstrap # Base yamls which acts as base for all zone/bootstrap specific patches
│   ├── istio
│   │   ├── <YAMLS>
│   │   ╰── istio-flux-kustomization.yaml # Flux kustmzn: applies kustomization for this dir
│   ├── cluster-baseline-settings
│   │   ╰── <YAMLS>
│   ╰── kube-system
│       ├── <YAMLS>
│       ╰── azm-flux-kustomization.yaml # Flux kustmzn: applies kustomization for this dir
├── bootstrap-dev
│   ├── cluster-baseline-settings
│   │   ├── kustomization.yaml # k8s kustmzn: Specifies resource to apply and values to path (values-<app>.yaml)
│   │   ├── values-<app>.yaml # Patches resource from base/bootstrap folder
│   │   ╰── cluster-baseline-flux-kustomization.yaml # Flux kustmzn: applies kustomization for this dir
│   ╰── *(2)kustomization.yaml # k8s kustmzn: applies cluster-baseline-settings/kustomization.yaml, then base/bootstrap
╰─── bootstrap-pre
        ╰── cluster-baseline-settings
            ╰── <similar yamls as bootstrap-dev>
```

## Zone specific directory (e.g. `deploy/dev-ngsa-asb-eastus`)

```bash
# Showing EastUS dev dir structure as example. Other cluster dir structures should be fairly similar
deploy/dev-ngsa-asb-eastus
├── fluentbit
│   ├── <YAMLS>
│   ╰── fluentbit-flux-kustomization.yaml # Flux kustmzn: applies kustomization for this dir
├── flux-kustomization
│   ├── *(3)eastus-dev-kustomization.yaml # Flux kustmzn: applies kustomization for this dir
│   ╰── kustomization.yaml # k8s kustmzn: Applies yaml resources in specific order
├── istio
│   ├── <YAMLS>
│   ╰── istio-flux-kustomization.yaml # Flux kustmzn: applies kustomization for this dir
├── loderunner
│   ├── dev/loderunner
│   │   ╰── <YAMLS>
│   ╰── loderunner-flux-kustomization.yaml # Flux kustmzn: applies kustomization for this dir and subdir
├── monitoring
│   ├── grafana
│   │   ├── <YAMLS>
│   │   ╰── dashboards<dir have yamls>
│   ├── thanos
│   │   ╰── <YAMLS>
│   ├── <YAMLS>
│   ├── kustomization.yaml # k8s kustmzn: Applies yaml resources in specific order
│   ╰── monitoring-flux-kustomization.yaml # Flux kustmzn: applies kustomization for this dir and subdirs
╰── ngsa
    ├── dev
    │   ╰── ngsa<dirs and YAMLS>
    ├── <YAMLS>
    ╰── ngsa-flux-kustomization.yaml
```

> *`(1)`, `(2)` and `(3)` represents the order of operations (`kubectl apply`) to setup a cluster with Flux GitOps.
>
> See the flowcharts below for order of operations and detailed chart of dependencies

## Directory Operation Flowchart

```mermaid
flowchart TD
    subgraph Legend
    flux-nodes("flux node")
    k8s_nodes["k8s kustomization node"]:::k8s
    yamls{{standard yaml node}}:::other
    end
    classDef k8s stroke:#a71
    classDef other stroke:#691
    classDef start fill:#f121,stroke:#099,stroke-width:2px;
```

### `flux-init` flowchart

```mermaid
flowchart LR
    classDef k8s stroke:#a71
    classDef other stroke:#691
    classDef start fill:#f121,stroke:#099,stroke-width:2px;
    apply[["kubectl apply -k"]]:::start --> k8skust[kustomization.yaml]:::k8s

    subgraph "Directory: flux-init"
        k8skust -->|applies| repo(gotk-repo.yaml)
        k8skust -->|applies| sync(gotk-sync.yaml)
        k8skust -->|applies| comp{{gotk-components.yaml}}
        sync    -.reconciles/syncs.-> k8skust
    end

    subgraph "(1) Deploy Flux"
        apply
    end
```

### `bootstrap` flowchart

```mermaid
flowchart LR
    classDef k8s stroke:#a71
    classDef other stroke:#691
    classDef start fill:#f121,stroke:#099,stroke-width:2px;
    
    %% Node definitions
    k8skust_root[kustomization.yaml]:::k8s
    k8skust_cb[kustomization.yaml]:::k8s
    base_kube[kustomization.yaml]:::k8s
    base_istio[kustomization.yaml]:::k8s
    base_cb[kustomization.yaml]:::k8s
    flux-kust(flux-kustomziation.yaml)
    values-kured[values-kured.yaml]:::k8s
    other-yamls{{"other-yamls"}}:::other
    bcb_yaml{{"other-yamls"}}:::other

    bistio_yaml{{"other-yamls"}}:::other
    bistio_flux("flux-kustomziation.yaml")

    bksys_yaml{{"other-yamls"}}:::other
    bksys_flux("flux-kustomziation.yaml")

    %% Total graph
    apply[["kubectl apply -k"]]:::start --> k8skust_root
    k8skust_root -->|applies| k8skust_cb
    k8skust_root -->|applies| base_kube
    k8skust_root -->|applies| base_istio

    %% bootstrap cluster-baseline
    k8skust_cb   -->|applies| flux-kust
    k8skust_cb   --used as patch--> values-kured
    k8skust_cb   -->|applies| other-yamls
    flux-kust    -.reconciles.-> k8skust_cb
    k8skust_cb   -->|patches using values-kured.yaml| base_cb
    
    %% base cluser-baseline-settings
    base_cb -->|applies| bcb_yaml

    %% base istio
    base_istio -->|applies| bistio_flux
    base_istio -->|applies| bistio_yaml
    bistio_flux -.reconciles.-> base_istio

    %% %base kube-system
    bksys_flux -.reconciles.-> base_kube
    base_kube -->|applies| bksys_yaml
    base_kube -->|applies| bksys_flux

    subgraph bst ["/deploy/bootstrap-dev"]
        subgraph bootstrap-cb ["/cluster-baseline-settings"]
            k8skust_cb
            other-yamls
            values-kured
            flux-kust
        end
        k8skust_root
    end
    subgraph base-boot ["/deploy/base/bootstrap"]
        subgraph kks ["/kube-system"]
            base_kube
            bksys_flux
            bksys_yaml
        end

        subgraph istio ["/istio"]
            base_istio
            bistio_flux
            bistio_yaml
        end
        subgraph base-cb ["/cluster-baseline-settings"]
            base_cb
            bcb_yaml
        end

    end
    subgraph "(2) Deploy bootstrap"
        apply
    end
    bootstrap-cb o-..-o base-cb
```

### Zone specific flowchart

> Showing `deploy/dev-ngsa-asb-eastus`

```mermaid
flowchart LR
    classDef k8s stroke:#a71
    classDef other stroke:#691
    classDef start fill:#f121,stroke:#099,stroke-width:2px;
    
    %% Node definitions
    root-flux(flux-kustomization.yaml)
    root-k8skust[kustomization.yaml]:::k8s
    ngsa-flux(flux-kustomization.yaml)
    ngsa-yamls{{"all-yamls-recursive"}}:::other
    lr-flux(flux-kustomization.yaml)
    lr-yamls{{"all-yamls-recursive"}}:::other
    mon-flux(flux-kustomization.yaml)
    mon-k8skust[kustomization.yaml]:::k8s
    mon-prom{{"prometheus-yamls"}}:::other
    mon-grafana-dash{{"dashboard-yamls*"}}:::other
    mon-grafana{{"grafana-yamls*"}}:::other
    fb-flux(flux-kustomization.yaml)
    fb-yamls{{"all-yamls-recursive"}}:::other
    istio-flux(flux-kustomization.yaml)
    istio-yamls{{"all-yamls-recursive"}}:::other

    apply[["kubectl apply -f"]]:::start --> root-flux

    root-flux -.reconciles.-> root-k8skust
    root-k8skust -->|applies| ngsa-flux
    root-k8skust -->|applies| fb-flux
    root-k8skust -->|applies| mon-flux
    root-k8skust -->|applies| istio-flux
    root-k8skust -->|applies| lr-flux

    %% ngsa
    ngsa-flux -.reconciles.->ngsa-yamls
    %% fb
    fb-flux -.reconciles.-> fb-yamls
    %% mon
    mon-flux -.reconciles.-> mon-k8skust
    mon-k8skust -->|applies|mon-prom
    mon-k8skust -->|applies|mon-grafana-dash
    mon-k8skust -->|applies|mon-grafana
    %% istio
    istio-flux -.reconciles.-> istio-yamls
    %% lr
    lr-flux -.reconciles.-> lr-yamls


    subgraph flux-k["/flux-kustomization"]
        root-flux
        root-k8skust
    end
    subgraph ngsa["/ngsa"]
        ngsa-flux
        ngsa-yamls
    end
    subgraph fb["/fluentbit"]
        fb-flux
        fb-yamls
    end
    subgraph mon["/monitoring"]
        mon-flux
        mon-k8skust
        mon-prom
        mon-grafana-dash
        mon-grafana
    end
    subgraph istio["/istio"]
        istio-flux
        istio-yamls
    end
    subgraph lr["/loderunner"]
        lr-flux
        lr-yamls
    end

    subgraph "(3) Zone Deployment"
        apply
    end
```
