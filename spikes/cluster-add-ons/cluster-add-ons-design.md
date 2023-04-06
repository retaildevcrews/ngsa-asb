# Deploying Add-ons to K8's Clusters

## What is a cluster add-on?

An add-on is component that is deployed to a Kubernetes cluster at the cluster level.  These add-ons are components leveraged by the applications that are deployed to the cluster.  For instance, application team may want their deployed application to provide metrics data to Prometheus, in this case the infrastructure/ops team would install the prometheus operator after cluster is created.

Given that there may be a large number of these add-ons and that infrastructure/ops teams could be managing thousands of clusters, there is a desire to have an automated way to deploy and maintain these add-ons on the clusters.

## Needs/Functionality

### General

- Add-ons should be able to be installed via various methods: HELM, Kubectl, shell scripts, etc.
- Add-ons should be able to be deployed to thousands of clusters - baseline 25k
- Add-on install/upgrade/removal should be performed in an automated fashion
- Add-ons should be validated after install
- What add-ons get deployed to what clusters should be able to be defined by the person responsible for the cluster
- Add-ons should be able to require dependencies to be available before they are installed

### Add On Management

- Which add-ons are available to be installed to the clusters should be able to be managed by the individuals responsible for the add on and not the individuals responsible for the cluster
- Add-on managers should be able to make new versions of add-ons

### Observability

- Visibility to what add-ons and their versions are installed in each cluster
- Visibility to status of install
- Visibility to result of install (success/failure)

## Questions

- What is the trigger for add-ons being installed to cluster?
- How are add-ons selected to be added to clusters?
