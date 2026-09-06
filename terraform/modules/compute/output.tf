#Writing the output module for the linux compute VM

output "vm_public_ip"{
    description     = "Public IP address of the VM"
    value           = azurerm_public_ip.main.ip_address
}

output "vm_id" {
    description    = "Resource ID of the VM"
    value          = azurerm_linux_virtual_machine.main.id
}

output "nsg_id"{
    description    = "Resource ID of the NSG, for later diagnostic settings"
    value          = azurerm_network_security_group.main.id 
}
