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


