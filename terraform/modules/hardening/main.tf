resource "azurerm_secruity_center_subscription_pricing" "vm"{
    tier = "Standard"
    resource_type = "VirtualMachines"
}