output "storage_account_id" {
  description = "Resource ID of the storage account"
  value       = azurerm_storage_account.main.id
}
output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "primary_blob_endpoint" {
  description = "Primary blob service endpoint URL"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "container_name" {
  description = "Name of the blob container"
  value       = azurerm_storage_container.main.name
}