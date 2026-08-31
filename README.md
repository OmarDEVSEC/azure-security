# azure-security
End-to-end Azure security modules: Deployed via Terraform, Defender for Cloud, KQL detection, and remediated through infrastructure as code.

# Monitoring Module

The monitoring module provides subscription-wide cost and service health oversight, deployed independently from the lab infrastructure so it survives `terraform destroy` cycles on the resources being tested.

**What it deploys:**
- **Action Group** (`ag-security-lab-alerts`) — a shared notification channel that routes alerts to email. Referenced by both the budget and service health alerts below, so any future alert can reuse it rather than duplicating notification config.
- **Consumption Budget** — a subscription-level budget with alert thresholds at 80% and 100% of a configurable monthly amount, notifying via the action group before spend gets out of hand.
- **Service Health Alert** (`service-health-alerts`) — watches for Azure platform incidents and planned maintenance events affecting the subscription, separate from monitoring the lab's own resources.

**Design decisions:**
- Deployed into its own resource group (`rg-monitoring`), isolated from the lab's resource group (`rg-azure-security`) — this means the lab environment can be torn down and rebuilt between sessions without losing budget/health alerting
- Scoped to the entire subscription rather than a single resource group, so it catches spend and health issues regardless of what gets built next in this project

![Monitoring resources deployed in Azure portal](docs/monitoring-resources.png)

*Action group and service health alert rule deployed to `rg-monitoring`, confirmed via Azure portal.*


# Static Web App Module

Brings the existing, already-live portfolio site (`omardevsec.pro`) under Terraform management via `terraform import`, rather than redeploying it from scratch — this preserves the live site, its GitHub Actions deployment pipeline, and its history.

**What it manages:**
- `azurerm_static_web_app` resource, imported from an existing Static Web App originally created manually in the Azure portal
- Tags (`PersonalSite = "1"`) brought into the config to match the real resource exactly, avoiding drift

**Design decision — resource type migration:**
The original plan used `azurerm_static_site`, but the first `terraform plan` after import surfaced a deprecation warning: `azurerm_static_site` is deprecated in favor of `azurerm_static_web_app` and will be removed in a future provider release. Since this was still early in bringing the resource under management, the resource type was migrated immediately rather than building on a deprecated type.

## Setup notes / troubleshooting log

A running log of real issues hit during this project and how they were resolved — kept intentionally rather than only showing a clean end state.

## Setup notes
**MFA and subscription authentication**
`az login` initially failed with `AADSTS50076`, requiring multi-factor authentication on the tenant. Separately, the Azure subscription had moved to a `Disabled` state after the free-tier credit expired.

Resolved by:
- Enrolling in Azure AD MFA through the Azure portal
- Upgrading the subscription to Pay-As-You-Go to reactivate it
- Confirming `az account show` returned an active, enabled subscription before proceeding with Terraform

This is also why the monitoring module (budget alerts, service health alerts) was deployed first, before any other lab infrastructure — to guard against unexpected spend now that the subscription bills for real.

**Duplicate `required_providers` block**
Terraform errored with `Duplicate required providers configuration` after a `required_providers` block for the `docker` provider was added directly to `main.tf`, conflicting with the existing `required_providers` block in `terraform.tf`. Terraform only allows one `required_providers` block per module, combined across all files.

Resolved by consolidating both provider declarations into a single block in `terraform.tf`:
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.87.0"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}
```

**Static Web App import — deprecated resource type**
After successfully running `terraform import` against the live Static Web App using `azurerm_static_site`, `terraform plan` returned:
```
Warning: Deprecated Resource
This resource has been deprecated in favour of `azurerm_static_web_app` and will be removed in a future release.
```
The same plan also revealed a real drift: an existing `PersonalSite = "1"` tag on the live resource wasn't declared in Terraform, which would have caused `apply` to delete it.

Resolved by:
1. Adding the missing tag into the resource block so Terraform's config matched reality
2. Migrating the resource type from `azurerm_static_site` to `azurerm_static_web_app`
3. Removing the old resource from state (`terraform state rm`) and re-importing under the new resource type
4. Confirming a clean `terraform plan` — "No changes" — before running `apply`, since this is a live, public-facing resource rather than disposable lab infrastructure

**General debugging habits established**
- `terraform validate` is the authoritative check when an editor's inline error panel (e.g. VS Code's Terraform extension) shows stale or conflicting errors after a file edit
- Empty module files can pass `terraform init` and `validate` cleanly while producing an incomplete `plan` — worth directly `cat`-ing files to confirm actual saved content when a plan's resource count doesn't match expectations
- For any resource that already exists in Azure (rather than being created fresh), always run `terraform plan` immediately after import and treat anything other than "No changes" as something to resolve before `apply` — never apply blind against a live resource


## Storage Module

Deploys a private-by-default storage account and blob container, intended later as the target for a deliberate misconfiguration in Phase 3 (e.g. public blob exposure or SAS token abuse).
 
**What it deploys:**
- **Storage Account** — `Standard` tier, `LRS` replication (cheapest option, appropriate for a lab environment that gets torn down between sessions)
- **Blob Container** — private access by default
**Security baseline set at creation:**
- `https_traffic_only_enabled = true` — rejects unencrypted HTTP connections
- `allow_nested_items_to_be_public = false` — account-level control blocking public blob access even if a container's access type is later misconfigured (defense in depth)
- `container_access_type = "private"` — no anonymous read access
This "secure by default" baseline is intentional — Phase 3 will deliberately weaken specific settings here to simulate a real misconfiguration, then Phase 4 will detect and remediate it back to this state via Terraform.

## Storage Module Setup Notes / Troubleshooting Log

**Provider version mismatch — `azurerm_storage_container` argument name**
Initial code used `storage_account_id` to link the container to its parent storage account, based on current Terraform Registry documentation. This produced an error because the project is pinned to `azurerm ~> 3.0`, and `storage_account_id` is only valid starting in provider version 4.x — version 3.x requires `storage_account_name` (a string reference) instead.
 
Resolved by using the version-correct argument:
```hcl
resource "azurerm_storage_container" "main" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}
```
Lesson: Registry documentation defaults to showing the latest provider version's syntax, which can silently mismatch an older pinned version. Confirm the active provider version (`terraform providers`) before trusting an argument name from docs.
 
**Running Terraform from inside a module folder**
`terraform plan` was run from inside `modules/storage/` directly rather than from the project root. Since a module has no provider configuration of its own, this produced a cascade of misleading errors: interactive prompts for the module's own variables, followed by `Invalid provider configuration` and a missing `features` argument — because the real `provider "azurerm" { features {} }` block only exists in the root `providers.tf`, which isn't visible from inside a module folder.
 
Resolved by returning to the project root (`azure-security/terraform`) before running any Terraform command. Modules are never invoked directly — they're only executed through the root configuration's `module` block.
 
**Module call argument errors**
The `module "storage"` block in root `main.tf` had three issues caught before `apply`:
- `resource_group_name` referenced the resource object itself (`azurerm_resource_group.SecLab`) instead of its `.name` attribute, which the module's `string`-typed variable requires
- `location` was hardcoded as `"Central US"` (with a space), inconsistent with the `"centralus"` format Azure returns elsewhere in the project, risking phantom diffs on future plans
- `storage_account_name` contained uppercase letters, which Azure storage account names don't allow (lowercase letters and numbers only, 3-24 characters)
Resolved by referencing the resource group's real attributes directly (`azurerm_resource_group.SecLab.name`, `azurerm_resource_group.SecLab.location`) rather than hardcoding values that could drift, and switching the storage account name to all-lowercase.