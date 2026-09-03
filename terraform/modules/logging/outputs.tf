# working on the outputs for logging module

output "workspace_id"{
    description = "Resource ID of the Log Analytics workspace"
    value       =  azurerm_log_analytics_workspace.main.id
}

output "workspace_name"{
    description =  "Name of the Log Analytics workspace"
    value       =  azurerm_log_analytics_workspace.main.name
}

//workspace id matters: Every diagnostic setting you add in phase 2 (for storage, Key Vault, etc)
// needs to reference workspace id as its destination having it as a clean output means each future module can just
// take log analytics workspace ID