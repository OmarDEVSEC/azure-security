#outputs file for the key vault

output "key_vault_id"{
    description   = "Resource ID of the Key vault"
    value         = azurerm_key_vault.main.id
}

output "key_vault_uri"{
    description = "URI used to access secrets/keys/certs in this vault"
    value       = azurerm_key_vault.main.vault_uri
}