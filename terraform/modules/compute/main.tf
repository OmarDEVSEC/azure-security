#Generating VM resource details, such as nmae address location, etc..

resource "azurerm_virtual_network" "main"{
    name                = "vnet-azsec"
    address_space       =["10.10.0.0/16"]
    location            = var.location
    resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "main"{
    name                 = "subnet-azsec"
    resource_group_name  = "var.resource_group_name"
    virtual_network_name = "azurerm_virtual_network.main.name"
    address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_security_group" "main"{
    name                 = "nsg-azsec"
    location             = var.location
    resource_group_name  = var.resource_group_name 


    security_rule{
        name              = "allow_ssh_for_me"
        priority          = 100
        direction         = "Inbound"
        access            = "Allow"
        protocol          = "Tcp"
        source_port_range = "*"
        destination_port_range = "22"
        source_address_prefix = var.allowed_ssh_source_ip
        destination_address_prefix = "*"
    }
}

resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_public_ip" "main"{
    name                = "pip-azsec"
    location            = var.location
    resource_group_name = var.resource_group_name
    allocation_method   = "Static"
    sku                 = "Standard"

}

resource "azurerm_network_inteface" "main"{
    name                = "nic-azsec"
    location            = var.location
    resource_group_name = var.resource_group_name

    ip_configuration {
        name                           = "internal"
        subnet_id                      = azurerm_subnet.main.id
        private_ip_address_allocations = "Dynamic"
        public_ip_address_id           = azurerm_public_ip.main.id
    }
}


resource "azurerm_linux_virtual_machine" "main" {
    name                = var.vm_name
    resource_group_name = var.resource_group_name
    location            = var.location
    size                = var.vm_size
    admin_username      = var.admin_username

    network_interface_ids = [
        azurerm_network_interface.main.id
    ]

    admin_ssh_key{
        username        = var.admin_username
        public_key      = var.ssh_public_key
    }
    disable_password_authentication = true

    os_disk{
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference{
        publisher            = "Canonical"
        offer                = "0001-com-ubuntu-server-jammy"
        sku                  = "22_04-lts-gen2"
        version              = "latest"
    }

    tags = {
        project = "azure-security"
    }
}
