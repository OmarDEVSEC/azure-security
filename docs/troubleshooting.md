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
