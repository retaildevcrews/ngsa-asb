# Application Gateway Restart Automation

The instructions below describe how to implement an Azure Automation Runbook that will automate and schedule stopping and starting the application gateways on each spoke. Though the runbook enables stopping and restarting the application gateways, the scheduled jobs created in this section only restart the application gateways.

## Prerequisites

It is assumed that the Firewall Automation has already been set up, as some of the infrastructure created in that process will be reused here.

## Set Environment Variable Values