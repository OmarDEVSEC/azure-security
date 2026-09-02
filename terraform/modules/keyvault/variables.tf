# Continue phase 1 of the Azure Security project - create Variable for Keyvault

variable "resource_group_name"{
    description = "Resource group the key vault belongs to"
    type        = string
}

variable "location"{
    description = "Azure region for the Key Vault"
    type        = string
}

variable "key_vault_name"{
    description = "Globally unique name for the Key Vault (3-24 chars)"
    type        = string    
}


# New concept tenant_id: Key vault needs to know which Entra ID tenant governs access to it
variable "tenant_id"{
    description = "Entra tenant ID that owns the key vault"
    type        = string
}

variable "sku_name"{
    description = "Pricing tier: standard or premium"
    type        =  string
    default     = "standard"
}

variable "assign_to_principal_id"{
    description = "Object ID of the user/service prinicipal to grant KV amdin privilege"
    type        =  string
}
