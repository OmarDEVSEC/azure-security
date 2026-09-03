#Teraform deployment file: Resource groups/resources built from this file

// Resource group for monitoring called rg-monitoring
resource "azurerm_resource_group" "monitoring" {
  name     = "rg-monitoring"
  location = "Central US"
}

// Will hold storage, key vaults, VM and more
// kept seperate from monitoring - able to terraform destroy lab resource without touching monitoring
resource "azurerm_resource_group" "SecLab" {
  name     = "rg-azure-security"
  location = "Central US"
}


data "azurerm_subscription" "current" {}


//Calls the monitoring module
module "monitoring" {
  source                = "./modules/monitoring"
  resource_group_name   = azurerm_resource_group.monitoring.name
  location              = azurerm_resource_group.monitoring.location
  alert_email           = var.alert_email
  monthly_budget_amount = 15
  subscription_id       = data.azurerm_subscription.current.subscription_id
}

module "static_site" {
  source              = "./modules/static-site"
  resource_group_name = "RSG-PersonalSite"
  location            = "centralus"
  site_name           = "OmarDevSec"
}

module "storage" {
  source               = "./modules/storage"
  resource_group_name  = azurerm_resource_group.SecLab.name
  location             = azurerm_resource_group.SecLab.location
  storage_account_name = "securestorageomardev"
}


data "azurerm_client_config" "current" {}

module "keyvault" {
  source                 = "./modules/keyvault"
  resource_group_name    = azurerm_resource_group.SecLab.name
  location               = azurerm_resource_group.SecLab.location
  key_vault_name         = "omarazureseckv"
  tenant_id              = data.azurerm_client_config.current.tenant_id
  assign_to_principal_id = data.azurerm_client_config.current.object_id
}


module "logging" {
  source              = "./modules/logging"
  resource_group_name = azurerm_resource_group.SecLab.name
  location            = azurerm_resource_group.SecLab.location
  workspace_name      = "law-azure-security"
}