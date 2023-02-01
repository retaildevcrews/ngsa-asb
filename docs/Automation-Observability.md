# Azure Automation Account Observability

These instructions guide you through setting up observability for Azure Automation Account. Diagnostic settings and Grafana dashboards will be created, including guidance on how to use the information they provide.

## Diagram

```mermaid

sequenceDiagram
    Automation Runbook->>Log Analytics: send logs via diagnostic settings
    Azure Monitor Alert->>Log Analytics: query for failed jobs
    alt found failed jobs
        Log Analytics-->>Azure Monitor Alert: ;
        Azure Monitor Alert ->> Azure Monitor Action Group: trigger notifications and actions
    end
    Grafana Dashboard ->> Log Analytics: query job status logs via pre-configured data source
    Log Analytics -->> Grafana Dashboard: ;
    Grafana Dashboard ->> Grafana Dashboard: display job status information

```

## Prerequisites

These instructions assume the following resources have already been created as part of the [main infrastructure setup](/README.md).

- [Automation Account and Runbooks](/docs/Firewall-Automation.md)
- [Grafana](/monitoring/README.md)
- [Log Analytics](/README.md#2-createhubsh)

## Diagnostic Setting Setup

Set the environment variables described below for the Diagnostic Setting configuration.

```bash

# Name of the Diagnostic Setting
export DIAGNOSTIC_SETTING_NAME="automation-diagnostic-setting"

# Name of the Automation Account to attach the Diagnostic Setting to
export AUTOMATION_ACCOUNT_NAME=<name of automation account>

# Resource Group of the Automation Account to attach the Diagnostic Setting to
export AUTOMATION_ACCOUNT_RG=<resource group of automation account>

# Name of Log Analytics where logs will be sent
# Recommend using hub log analytics if automation affects both hub and spoke resources
export LA_WORKSPACE_NAME=<name of log analytics workspace>

# Resource group of Log Analytics where logs will be sent
export LA_WORKSPACE_RG=<resource group of log analytics workspace>

```

Run the script to create the Diagnostic Setting.

```bash

./scripts/Create-Automation-Diagnostics.sh

```

## Grafana Dashboard Setup

- TODO: how the grafana dashboard is setup with flux, including how to add to different clusters

## Troubleshooting Automation Runbook Jobs

Below, you'll find guidance on how to use the information from the diagnostic setting for troubleshooting.

### Troubleshooting with Grafana Dashboard

- TODO: how to use grafana dashboard for troubleshooting
  - what information is displayed in grafana dashboard?
  - how to interpret it?
  - when to take action?

### Troubleshooting with Log Analytics

Log Analytics has information about Jobs and their logs that can be used for further troubleshooting. Below are some example queries to get started.

Find error entries from the Job logs. This is useful when a Job is finished, encoutered errors, but the Job was marked as Completed instead of Failed.

```kql

AzureDiagnostics |
  where ResourceProvider == "MICROSOFT.AUTOMATION"
  and Category == "JobStreams"
  and StreamType_s == "Error" |
project TimeGenerated, JobId_g, ResourceGroup, Resource, ResultType, ResultDescription, RunbookName_s, StreamType_s |
order by TimeGenerated desc

```

Find Jobs that finished in a Failed stated.

```kql

AzureDiagnostics |
where ResourceProvider == "MICROSOFT.AUTOMATION"
  and Category == "JobLogs"
  and ResultType == "Failed" |
project TimeGenerated, JobId_g, ResourceGroup, Resource, ResultType, RunbookName_s |
order by TimeGenerated desc

```

View all log entries for a specific Job, filtering by the JobId_g field.

```kql

AzureDiagnostics |
where Category == "JobStreams"
  and JobId_g == "<replace with specific job id>" |
order by TimeGenerated desc

```

For more example queries when troubleshooting Automation runbook jobs, refer to this [Azure documentation](https://learn.microsoft.com/en-us/azure/automation/automation-manage-send-joblogs-log-analytics#sample-queries-for-job-logs-and-job-streams).

### Fixing issues

- TODO: how to potentially resolve specific issues. eg: manually start resource that was not restarted
  - start individual cluster example command
  - restart individual vmss example command

## TODO: add notes to eventual PR or as comment in task 1124

- removed alerts from the scope and added an item to the board for future discussion
- removed powershell updates from the scope and added an item to the board for future discussion
- using the dev hub log analytics for the diagnostic setting
  - automation account runbooks affect resources in dev, preprod, hub, and spoke
  - picked dev with the assumption that solution would go through more iterations before preprod
  - picked hub because it felt more natural to have spoke data in the hub instead of the other way around
- observed little to no changes in Log Analytics costs with new diagnostic setting sending logs
  - Jobs do not run often and they output minimal logs
- created a new dashboard directory for flux kustomization variable substitution
  - <https://fluxcd.io/flux/components/kustomize/kustomization/#variable-substitution>
  - needed a way to target specific dashboard config maps for variable substitution so other dashboards are not affected
  - an alternative is to reuse the existing kustomizations and disable specific ones with a special annotation, `kustomize.toolkit.fluxcd.io/substitute: disabled`
    - a potential downside is all current and future resources under the kustomization would require this annotation if substitution is not desired
