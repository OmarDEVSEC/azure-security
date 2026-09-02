# resource main file for the keyvault


resource "azurerm_key_vault" "main"{
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name

  enable_rbac_authorization = true

  purge_protection_enabled  = false

  tags = {
    project = "azure-security"
  }
}

resource "azurerm_role_assignment" "kv_admin"{
    scope                = azurerm_key_vault.main.id
    role_definition_name = "Key Vault Administrator"
    principal_id         = var.assign_to_principal_id

}
