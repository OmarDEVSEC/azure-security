# Troubleshooting Log

A running log of real issues hit during this project and how they were resolved — kept intentionally rather than only showing a clean end state.

## MFA and subscription authentication

`az login` initially failed with `AADSTS50076`, requiring multi-factor authentication on the tenant. Separately, the Azure subscription had moved to a `Disabled` state after the free-tier credit expired.

Resolved by:
- Enrolling in Azure AD MFA through the Azure portal
- Upgrading the subscription to Pay-As-You-Go to reactivate it
- Confirming `az account show` returned an active, enabled subscription before proceeding with Terraform

This is also why the monitoring module (budget alerts, service health alerts) was deployed first, before any other lab infrastructure — to guard against unexpected spend now that the subscription bills for real.

## Duplicate `required_providers` block
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
## Static Web App import — deprecated resource type

After successfully running `terraform import` against the live Static Web App using `azurerm_static_site`, `terraform plan` returned:

Warning: Deprecated Resource
This resource has been deprecated in favour of azurerm_static_web_app and will be removed in a future release.

The same plan also revealed a real drift: an existing `PersonalSite = "1"` tag on the live resource wasn't declared in Terraform, which would have caused `apply` to delete it.

Resolved by:
1. Adding the missing tag into the resource block so Terraform's config matched reality
2. Migrating the resource type from `azurerm_static_site` to `azurerm_static_web_app`
3. Removing the old resource from state (`terraform state rm`) and re-importing under the new resource type
4. Confirming a clean `terraform plan` — "No changes" — before running `apply`, since this is a live, public-facing resource rather than disposable lab infrastructure

## Provider version mismatch — `azurerm_storage_container` argument name

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

## Running Terraform from inside a module folder

`terraform plan` was run from inside `modules/storage/` directly rather than from the project root. Since a module has no provider configuration of its own, this produced a cascade of misleading errors: interactive prompts for the module's own variables, followed by `Invalid provider configuration` and a missing `features` argument — because the real `provider "azurerm" { features {} }` block only exists in the root `providers.tf`, which isn't visible from inside a module folder.

Resolved by returning to the project root (`azure-security/terraform`) before running any Terraform command. Modules are never invoked directly — they're only executed through the root configuration's `module` block.

## Module call argument errors

The `module "storage"` block in root `main.tf` had three issues caught before `apply`:
- `resource_group_name` referenced the resource object itself (`azurerm_resource_group.SecLab`) instead of its `.name` attribute, which the module's `string`-typed variable requires
- `location` was hardcoded as `"Central US"` (with a space), inconsistent with the `"centralus"` format Azure returns elsewhere in the project, risking phantom diffs on future plans
- `storage_account_name` contained uppercase letters, which Azure storage account names don't allow (lowercase letters and numbers only, 3-24 characters)

Resolved by referencing the resource group's real attributes directly (`azurerm_resource_group.SecLab.name`, `azurerm_resource_group.SecLab.location`) rather than hardcoding values that could drift, and switching the storage account name to all-lowercase.

## General debugging habits established

- `terraform validate` is the authoritative check when an editor's inline error panel (e.g. VS Code's Terraform extension) shows stale or conflicting errors after a file edit
- Empty module files can pass `terraform init` and `validate` cleanly while producing an incomplete `plan` — worth directly `cat`-ing files to confirm actual saved content when a plan's resource count doesn't match expectations
- For any resource that already exists in Azure (rather than being created fresh), always run `terraform plan` immediately after import and treat anything other than "No changes" as something to resolve before `apply` — never apply blind against a live resource

## Key Vault RBAC argument — provider version confusion
 
While configuring `azurerm_key_vault` for RBAC authorization, an error suggested the required argument was `rbac_authorization_enabled`:
```
Error: Missing required argument
The argument "rbac_authorization_enabled" is required, but no definition was found.
```
Using that name produced the opposite error:
```
Error: Unsupported argument
An argument named "rbac_authorization_enabled" is not expected here.
```
The contradiction was resolved by confirming the exact installed provider version:
```bash
terraform version
# + provider registry.terraform.io/hashicorp/azurerm v3.117.1
```
The property was renamed from `enable_rbac_authorization` to `rbac_authorization_enabled` starting in provider version **4.42.0**. On `v3.117.1`, only the original name is valid:
```hcl
resource "azurerm_key_vault" "main" {
  # ...
  enable_rbac_authorization = true
  purge_protection_enabled  = false
}
```
 
Lesson: when an error message references an argument name that itself then fails, don't trust the error's wording alone — confirm the exact provider version with `terraform version` and check which argument name applies to that specific version before changing code again. This is the second time in this project a provider version boundary (see also: the `azurerm_storage_container` argument change) has been the actual root cause behind a confusing error.
 
## Missing variable declaration — Key Vault role assignment
 
`main.tf` referenced `var.assign_to_principal_id` in the `azurerm_role_assignment` resource, but the corresponding `variable "assign_to_principal_id" {}` block wasn't present in `variables.tf`, producing:
```
Error: Reference to undeclared input variable
```
Resolved by adding the missing declaration to `modules/keyvault/variables.tf`:
```hcl
variable "assign_to_principal_id" {
  description = "Object ID of the user/service principal to grant Key Vault Administrator access"
  type        = string
}
```
Same category of issue as the earlier empty `modules/monitoring/main.tf` case — a resource referencing a variable that was never actually declared/saved in the module's `variables.tf`.
 

 ## Logging module — running Terraform from inside the module folder (recurring issue)
 
`terraform plan` was run from inside `modules/logging/` rather than the project root, producing an interactive prompt for `location` and later an error that `workspace_name` was "not set" at the root module level. This is the same root cause as the earlier storage module issue: a module folder has no provider configuration of its own, so running Terraform commands from inside one causes it to be misread as a standalone root config.
 
Resolved the same way as before — confirming the working directory with `pwd` and returning to the project root (`azure-security/terraform`) before running any Terraform command.
 
Noted as a recurring pattern rather than a one-off: worth building the habit of running `pwd` automatically before any `terraform` command, especially right after `cd`-ing into a module folder to create files.
 
## Typo — `azurerm_resource_group_name` vs `azurerm_resource_group`
 
The `module "logging"` block in root `main.tf` referenced a resource type `azurerm_resource_group_name`, which doesn't exist — the actual resource type is `azurerm_resource_group`, with `.name` as an attribute read on it, not part of the type name itself:
```
Error: Reference to undeclared resource
A managed resource "azurerm_resource_group_name" "SecLab" has not been declared in the root module.
```
Resolved by correcting the reference to `azurerm_resource_group.SecLab.name` (and the equivalent `.location` reference below it).

## Compute module — quoted references instead of interpolation

The `azurerm_subnet` resource in `modules/compute/main.tf` had its cross-references written as literal strings instead of interpolated values:
```hcl
resource_group_name  = "var.resource_group_name"
virtual_network_name = "azurerm_virtual_network.main.name"
```
`terraform plan` showed these as plain text rather than `(known after apply)`, which would have caused `apply` to fail — Terraform would have tried to create the subnet inside a resource group literally named `"var.resource_group_name"`, which doesn't exist.

Resolved by removing the surrounding quotes so both lines are real references, not strings:
```hcl
resource_group_name  = var.resource_group_name
virtual_network_name = azurerm_virtual_network.main.name
```
Lesson: always check `plan` output for suspiciously literal-looking values on attributes that should read `(known after apply)` — quoted references are easy to introduce by habit when every other line in a `.tf` file legitimately uses quotes for string literals.

## VM SKU capacity — `SkuNotAvailable`

`terraform apply` failed while creating the VM:
```
Error: SkuNotAvailable: The requested VM size for resource 'Following SKUs have failed for Capacity Restrictions: Standard_B1s' is currently not available in location 'centralus'.
```
Switching to `Standard_B1ms` produced the identical error, ruling out a size-specific problem.

Investigated with:
```bash
az vm list-skus --size Standard_B1s --all --output table
```
This revealed the real cause: the subscription (recently upgraded from a free trial to Pay-As-You-Go) is restricted with `NotAvailableForSubscription` on nearly every mainstream region — `centralus`, `eastus`, `eastus2`, `westus2`, etc. — for `Standard_B1s`. Only a small set of regions showed `None` (no restriction): `DenmarkEast`, `IndiaSouthCentral`, `EastUS3`, `SoutheastUS`, `SouthCentralUS2`, `SaudiArabiaEast`, `WestCentralUSFRE`, among a few others.

This is a temporary, common restriction Azure applies to subscriptions with limited billing history, not a project misconfiguration. It's expected to lift on its own as the subscription accrues payment history.

## Region supports the VM size but not core networking

Switching to `eastus3` (one of the unrestricted regions from the SKU list) let the VM size validate, but `terraform apply` then failed creating the VNet, NSG, and public IP:
```
Error: LocationNotAvailableForResourceType: The provided location 'eastus3' is not available for resource type 'Microsoft.Network/virtualNetworks'.
```
The error's own region list confirmed `eastus3` isn't in Azure's supported list for `Microsoft.Network/*` resource types at all — it's a specialized/limited-availability region, not a general-purpose one.

Resolved by cross-referencing the SKU-availability list against Azure's networking-capable region list and choosing **`denmarkeast`**, which satisfies both. Since the whole compute module (VNet through VM) had already partially applied in `centralus` and then `eastus3` before this fix, changing `location` forced Terraform to destroy and recreate all 5 networking resources plus add the VM (`Plan: 6 to add, 0 to change, 5 to destroy`) — safe to apply, since no VM had ever successfully finished deploying and nothing of value existed yet.

Lesson: a region appearing in a SKU availability list only confirms compute capacity for that VM size — it says nothing about whether that same region supports the other resource types (networking, storage, etc.) the deployment also needs. Both need independent verification for an unfamiliar or restricted region.

## Compute module — confirmed working

After the region fix, `terraform apply` completed successfully: VNet, subnet, NSG, NSG association, public IP, NIC, and VM all provisioned in `denmarkeast`. SSH access confirmed using the RSA key from the allowed source IP, then the VM was deallocated (`az vm deallocate`) to stop compute billing while not in active use — the public IP and OS disk continue to bill at a small fixed rate regardless of VM power state, so a full `terraform destroy` of the compute module is the only way to reach zero cost during extended breaks.

docs/troubleshooting.md addition
markdown
## Hardening module — missing module output ("object with no attributes")

`terraform plan` failed on the new `module "hardening"` block:

Error: Unsupported attribute

on main.tf line 75, in module "hardening":
75: storage_account_id = module.storage.storage_account_id
├────────────────
│ module.storage is object with no attributes

This object does not have an attribute named "storage_account_id".

The cause wasn't the `hardening` module's code — it was that `modules/storage/outputs.tf` didn't exist yet. The Storage module had been created and applied back in Phase 1 without ever declaring any outputs, since nothing needed to consume its values at the time. With zero outputs declared, Terraform correctly treats `module.storage` as an object with no attributes, so any reference to `module.storage.<anything>` fails the same way regardless of what's inside the referencing module.

Resolved by creating `modules/storage/outputs.tf` with the needed outputs (`storage_account_id`, `storage_account_name`, `primary_blob_endpoint`, `container_name`).

Lesson: a module only exposes what its own `outputs.tf` declares — adding a new module that *consumes* another module's resource means checking that the other module actually exports it first, not assuming it does because the resource exists.

## Resource type typo — `azurerm_secruity_center_subscription_pricing`

Error: Invalid resource type

on modules/hardening/main.tf line 1, in resource "azurerm_secruity_center_subscription_pricing" "vm":
1: resource "azurerm_secruity_center_subscription_pricing" "vm"{

The provider hashicorp/azurerm does not support resource type "azurerm_secruity_center_subscription_pricing". Did
you mean "azurerm_security_center_subscription_pricing"?

Transposed letters in "security." Resolved by correcting to `azurerm_security_center_subscription_pricing` — Terraform's own suggestion matched exactly.

## Deprecated `log` block → `enabled_log`

`terraform plan` warned on both the Key Vault and NSG diagnostic settings:

Warning: Argument is deprecated
log has been superseded by enabled_log and will be removed in version 4.0 of the AzureRM Provider.

Not blocking, but fixed immediately since it's a straight syntax swap. `enabled_log` doesn't take an `enabled = true` line the way `log` did — the block's presence alone means it's active:
```hcl
enabled_log {
  category = "AuditEvent"
}
```
## Storage logging — metrics vs. logs live on different resource IDs

The first storage diagnostic setting only configured a `metric` block and left logging out entirely — easy to miss since every other resource in this module (Key Vault, NSG) needed just one `azurerm_monitor_diagnostic_setting` block covering both logs and metrics together.

Storage accounts don't work that way: the top-level `Microsoft.Storage/storageAccounts` resource only supports metric categories (`Transaction`, `Capacity`) — it has no log categories at all. Blob read/write/delete logging only exists on the blob service sub-resource, reached with a resource ID of `"${storage_account_id}/blobServices/default/"`, not the storage account ID itself.

Resolved by adding a second `azurerm_monitor_diagnostic_setting` resource (`storage_blob`) targeting that sub-resource path, alongside the original account-level one (left unchanged for metrics).

While fixing this, a typo on the first apply attempt —

Error: creating Monitor Diagnostics Setting "diag-storage-blob" ...: unexpected status 400 (400 Bad Request)
with response: {"code":"BadRequest","message":"Category 'StorageDelet' is not supported."}

— was a dropped letter in `"StorageDelet"`, caught immediately by Azure's own 400 response rather than at `plan` time, since category name validity for a diagnostic setting is checked against the live API, not against the provider schema. Resolved by correcting to `"StorageDelete"`.

Lesson: same family of issue as the Static Web App's deprecated resource type and the Key Vault RBAC argument rename — don't assume a resource type's sub-resources share the same capabilities as the parent. Check Azure's documentation for which categories/resource scope a diagnostic setting actually supports before assuming one setting covers everything.

## VM agent drift — `vm_agent_platform_updates_enabled`

An `apply` for an unrelated change (adding the hardening module) also showed an in-place update to the already-deployed Compute module's VM:

~ vm_agent_platform_updates_enabled = true -> false

Nothing in `modules/compute/` was touched. This is drift between the provider's current default for that argument and the value Azure had set on the live VM — not a configuration problem, and not destructive. Applied as-is; noted here since the Compute module was otherwise considered "done" after SSH verification, and it's worth remembering that a live VM resource can still show incidental drift on unrelated `apply` runs.

## Attack A — plan shows 0 to add for a resource that was already applied

While preparing Attack A, the Activity Log diagnostic setting (`activity_log`) had been added to `modules/hardening/main.tf`, but `terraform plan` reported `0 to add, 5 to change` with no mention of it.

Checked state directly instead of re-reading the code:
```bash
terraform state list | grep activity_log
# module.hardening.azurerm_monitor_diagnostic_setting.activity_log
```
The resource was already in state. It had been applied in an earlier run, so a plan correctly had nothing to add.

Lesson: "0 to add" doesn't mean a resource is missing from the config. It can mean the resource is already applied. When a plan doesn't match expectations, `terraform state list` is the fastest way to tell "not in config" from "already in state."

## Azure CLI — `--auth-mode` typo and broken line continuations

Uploading the test file failed:

az storage blob upload: 'mode' is not a valid value for '--auth-mode'. Allowed values: login, key.

Two causes:
- The flag was typed `--auth mode key` (space instead of a hyphen). The CLI accepts `--auth` as an abbreviation of `--auth-mode`, so it read `mode` as that flag's value
- The multi-line command with `\` line continuations was pasted as a single line, and a later edit also ran two arguments together (`AzureSecSensitiveinfo.csv--auth-mode`), so the CLI parsed them as one filename

Resolved by running the command as a single line with correct flag names and spacing:
```bash
az storage blob upload --account-name securestorageomardev --container-name privatedata --name AzureSecSensitiveinfo.csv --file AzureSecSensitiveinfo.csv --auth-mode key
```
Lesson: `\` continuations only work when each part sits on its own line. For pasted commands, use a single line. And an error that names a valid flag with a wrong value usually means a flag name was split or abbreviated by accident.

## Plan is not apply — `PublicAccessNotPermitted` after the "change"

The first anonymous `curl` after the attack change still failed:

<Error><Code>PublicAccessNotPermitted</Code><Message>Public access is not permitted on this storage account.

The Terraform change (`allow_nested_items_to_be_public = true`, container `private -> blob`) had been previewed with `terraform plan` but not yet applied. Checking live state confirmed it:
```bash
az storage account show --name securestorageomardev --resource-group rg-azure-security --query allowBlobPublicAccess
# false
```
Resolved by running `terraform apply` from the project root. After that, the same check returned `true` and the anonymous read succeeded.

Lesson: when a result contradicts the code, check live state with the Azure CLI before assuming a propagation delay. `plan` previews a change and only `apply` makes it.

## A test that fails for the wrong reason proves nothing

After reverting Attack A, the verification `curl` failed:

curl: (7) Failed to connect to securestorageomardev.blob.core.winows.net port 443

The URL had a typo (`winows.net` instead of `windows.net`). The failure was a connection error against a hostname that doesn't exist, not an answer from Azure, so it said nothing about whether the revert worked. Re-running with the correct URL returned the expected `PublicAccessNotPermitted` response from Azure itself.

Lesson: a verification only counts if it fails (or passes) for the intended reason. An error body from the service, such as an Azure XML error, is evidence. A DNS or connection error is not.

## Recurring plan noise — diagnostic settings and VM agent drift

Every `plan` during this phase showed in-place changes that weren't part of the work:
- **Diagnostic settings** (`storage`, `storage_blob`): Terraform removed and re-added the `Transaction` metric block, and dropped a `Capacity` block (`enabled = false`) plus empty `retention_policy` blocks. Azure returns default fields the config doesn't declare, so Terraform keeps trying to reconcile them. Cosmetic and harmless
- **VM** (`vm_agent_platform_updates_enabled = true -> false`): this appeared on every plan and reappeared after an apply that reported success, because Azure keeps the live value at `true`. Setting `vm_agent_platform_updates_enabled = true` explicitly in the compute module matches reality and should end the recurring diff. [Status: confirm whether this was applied]

Lesson: persistent plan diffs on unchanged resources are provider-versus-API default mismatches. Understand them once and note them, so that a real change is easy to spot among them.

## README screenshots not rendering

Screenshots added to the Attack A section showed as plain text in the README preview:
```markdown
- `/docs/AzureAttackA/AzSensitiveInfoBlobUpload.png`: the Terraform change...
```
Two causes: the paths were wrapped in backticks (rendered as inline code, not images), and they began with a leading slash, which points at the drive root in local previews.

Resolved by using Markdown image syntax with a path relative to the README:
```markdown
![alt text](docs/AzureAttackA/AzSensitiveInfoBlobUpload.png)
```
Lesson: `![alt](path)` embeds an image. Backticks display the path as text. Relative paths without a leading slash render in both VS Code and GitHub.