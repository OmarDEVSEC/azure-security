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
 