output "action_group_id"{
    description = "Action group that detection alerts notify"
    value       = azurerm_monitor_action_group.main.id
}

