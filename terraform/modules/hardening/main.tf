resource "azurerm_security_center_subscription_pricing" "vm" {
  count         = var.enable_defender ? 1 : 0
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

#Diagnostic setting for storage account

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "diag-storage"
  target_resource_id         = var.storage_account_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "Transaction"
  }
}

#Diagnostic settings for the azure keyvault
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "diag-keyvault"
  target_resource_id         = var.key_vault_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }
  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "nsg" {
  name                       = "diag-nsg"
  target_resource_id         = var.nsg_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"

  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"

  }
}

#Diagnostic setting for storage account blob service

resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  name                       = "diag-storage-blob"
  target_resource_id         = "${var.storage_account_id}/blobServices/default/"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
  }
}

data "azurerm_subscription" "current" {}

resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "diag-activity-log"
  target_resource_id         = data.azurerm_subscription.current.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "Administrative" }
  enabled_log { category = "Security" }
  enabled_log { category = "Policy" }
}