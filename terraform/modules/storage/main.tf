#Generating the storage resources within this main file under storage directory

resource "azurerm_storage_account" "main" {
    name = var.storage_account_name
    resource_group_name = var.resource_group_name
    location            = var.location
    account_tier        = var.account_tier
    account_replication_type = var.replication_type

    https_traffic_only_enabled  =   true
    allow_nested_items_to_be_public = false

    tags = {
        project = "azure-security"
    }
}

resource "azurerm_storage_container" "main" {
    name        = var.container_name
    storage_account_name = azurerm_storage_account.main.name
    container_access_type = "private"
}
