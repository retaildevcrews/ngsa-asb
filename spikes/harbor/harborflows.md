# Scenarios

## Pull image from Harbor Registry

This is the generic flow for pulling an image that exists in the Harbor registry (image cache).

```mermaid
sequenceDiagram
    participant action  as Action 
    participant docker  as Docker
    participant harbor  as Harbor
    
    action     ->> docker: Docker Pull executed
    docker     ->> harbor: Image requested from Harbor
    alt If scanned image <br> meets vulnerability requirements <br> or image has not been scanned
        harbor     --)  docker: Image returned to docker
        end
```

## Proxy Cache - Image Pull from External Registry through Harbor

In Proxy Cache setup, there is no ability to push to external registry
> **_NOTE:_**  It is important to note that in this scenario if the image is pulled from the external registry it will be returned to docker irrespective of vulnerability results as at the time it is returned the image has not been scanned.

```mermaid
sequenceDiagram
    participant action  as Action 
    participant docker  as Docker
    participant harbor  as Harbor Container <br> Registry
    participant ecr     as External Container Registry

    action     ->> docker: Docker Pull executed
    docker     ->> harbor: Image requested from Harbor
    alt If image doesn't exist in the container registry
        harbor    ->> ecr: Retrieve from source <br> (External Registry)
        ecr        --) harbor: Image from source stored <br> in the Harbor Container Registry
        end
    alt If scanned image <br> meets vulnerability requirements <br> or image has not been scanned
        harbor     --)  docker: Image returned to Docker <br> from Harbor Container Registry
        end
```

## Replicate images from external registry into Harbor Registry

Harbor can pull images from external container registries on a schedule or triggered manually.

```mermaid
sequenceDiagram
    participant action  as Replication Rule Trigger
    participant replicator  as Harbor Replication Rule
    participant hrCache as Harbor Container Registry
    participant scan    as Vuln Scanner
    participant ecr     as External Container Registry
    
    action      ->> replicator: Replication Rule run manualy <br> or as scheduled task
    replicator  ->> ecr: Image(s) requested from ECR
    ecr         --) hrCache: Image from source stored <br> in the Harbor Container Registry
    alt If image scanning is <br> configured and enabled
        hrCache ->> scan: Scan images for <br> vulnerabilities
        scan    --) hrCache: Results available to harbor container registry
        end
```

## Image Push to external registry

All images are stored in harbor registry, if scanner is turned on for project image is scanned before being made available to pull.  When pushing images to a Harbor instance, it is ensured that an image that has been loaded that violates the vulnerability threshold is not able to be retrieved from that Harbor instance.

```mermaid
sequenceDiagram
    participant action  as Action 
    participant docker  as Docker
    participant harbor  as Harbor Container Registry
    participant scan    as Vuln Scanner
    participant ecr     as External Container Registry

    action     ->> docker: Docker Push executed
    activate   harbor
    docker     ->> harbor: Image uploaded and stored <br> in Harbor Container Registry
    harbor    ->> scan: Cached image scanned <br> for vulnerabilities
    alt Image meets vulnerability threshhold 
        harbor    ->> ecr: Image is pushed to External Registry <br> (Images which violate vulnerability threshhold will <br> not be pushed to the external registry)
        end
    deactivate  harbor
```
