#Generating variables for the compute module and utilizing the DRY mehtod

variable "resource_group_name"{
    description = "Resource group for th VM and its networking configurations"
    type        = string
}

variable "location"{
    description = "Azure region the VM belongs to"
    type        = string
}

variable "vm_name"{
    description = "The name of the virtual machine"
    type        = string
    default     =  "linux-vm-azsecurity"
}

variable "vm_size"{
    description = "VM size - small to control costs"
    type        = string
    default     = "Standard_B1s"
}

variable "admin_username"{
    description = "Local amdin username for the VM"
    type = string
    default = "omaradmin"
}

variable "ssh_public_key"{
    description = "SSH public contents, used for login instead of a password"
    type        =  string 
}

variable "allowed_ssh_source_ip"{
    description = "Public IP CIDR allowed to reach ssh"
    type        =  string
}

