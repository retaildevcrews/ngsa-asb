# Scenarios

## Pull image from Harbor Registry

This is the generic flow for pulling an image that exists in the Harbor registry (image cache).

```mermaid
sequenceDiagram
    participant action  as Action 
    participant docker  as Docker CLI
    participant harbor  as Harbor
    
    action  ->> docker: Docker Pull executed
    activate action
    activate docker
    docker  ->> harbor: Image requested from Harbor
    activate harbor
    harbor  ->> harbor: Check image scan status
    alt Passed scan || First pull
        harbor -->> docker: Image returned to docker
    else vulnerabilities detected
        harbor -->> docker: Error returned
    end
    deactivate harbor
    docker -->> action: Harbor result returned to calling Activity
    deactivate docker
    deactivate action
    
```

## Proxy Cache - Image Pull from External Registry through Harbor

In Proxy Cache setup, there is no ability to push to external registry
> **_NOTE:_**  It is important to note that in this scenario if the image is pulled from the external registry it will be returned to docker irrespective of vulnerability results as at the time it is returned the image has not been scanned.

```mermaid
sequenceDiagram
    participant action  as Action 
    participant docker  as Docker CLI
    participant harbor  as Harbor
    participant ecr     as Source Container <br> Registry

    action  ->> docker: Docker Pull executed
    activate action
    activate docker
    docker  ->> harbor: Image requested from Harbor
    activate harbor
    alt Is imaged already cached?
        harbor  ->> ecr: Retrieve from source container registry
        activate ecr
        ecr    -->> harbor: Image from source stored <br> in the Harbor Container Registry
        deactivate ecr
    end
    alt Passed scan || First pull
        harbor -->> docker: Image returned to docker
    else vulnerabilities detected
        harbor -->> docker: Error message returned
    end
    deactivate harbor
    docker -->> action: Pull result returned to caller
    deactivate docker
    deactivate action
    
```

## Replicate images from external registry into Harbor Registry

Harbor can pull images from external container registries on a schedule or triggered manually.

```mermaid
sequenceDiagram
    participant action  as Scheduled or Manual <br> Trigger Mechanism
    participant replicator  as Harbor Replication Rule
    participant hrCache as Harbor Container Registry
    participant scan    as Vuln Scanner
    participant ecr     as External Container Registry
    
    action        -)+ replicator: Start replication
    replicator   ->>+ hrCache: Retrieve image from source
    hrCache      ->>+ ecr: Image pull
    ecr         -->>- hrCache: store in proxy cache
    hrCache       -)+ scan: Scan images for <br> vulnerabilities
    scan         --)- hrCache: Results available to harbor container registry
    hrCache     -->>- replicator: Image fetched and scan started
    replicator   --)- action: replication complete
```

## Image Push to Harbor

> **_NOTE:_** When pushing images to a Harbor instance, it is ensured that an image that has been loaded that violates the vulnerability threshold is not able to be retrieved from that Harbor instance.

```mermaid
sequenceDiagram
    participant action  as User or <br> Automation 
    participant docker  as Docker CLI
    participant harbor  as Harbor Container Registry
    participant scan    as Vuln Scanner

    action     ->>+ docker: Push issued
    docker     ->>+ harbor: Imaged pushed to Harbor
    harbor      -)+ scan: Cached image scanned <br> for vulnerabilities
    scan       --)- harbor: Results available
    harbor    -->>- docker: Receipt Acknowledge
    docker    -->>- action: command completed
    
```

## Image Push to external registry through Harbor

> **_NOTE:_** When pushing images to a Harbor instance, it is ensured that an image that has been loaded that violates the vulnerability threshold is not able to be retrieved from that Harbor instance.

```mermaid
sequenceDiagram
    participant action  as Action 
    participant docker  as Docker
    participant harbor  as Harbor Container Registry
    participant scan    as Vuln Scanner
    participant ecr     as External Container Registry

    action     ->> docker: Docker Push executed
    docker     ->> harbor: Image uploaded and stored <br> in Harbor Container Registry
    alt If vulnerability scanning is enabled
        harbor    ->> scan: Cached image scanned <br> for vulnerabilities
        scan      --) harbor: Results available to Harbor
        end
    alt Image meets vulnerability threshhold 
        harbor    ->> ecr: Image is pushed to External Registry <br> (Images which violate vulnerability threshhold will <br> not be pushed to the external registry)
        end
```
