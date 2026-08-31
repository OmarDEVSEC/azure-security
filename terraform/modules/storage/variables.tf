#Generating variables for the storage accounts that will be deployed via terraform

variable "resource_group_name" {
    description = "Resource group the storage account will belong to"
    type        =  string
}

variable "location"{
    description = "The azure region this storage account will belong to"
    type        =  string
}

variable "storage_account_name" {
    description =  "It is the globally unique name for the storage account (note: Lowecase letters only)"
    type        =   string
}

variable "account_tier" {
    description = "Performance tier: Standard or Premium"
    type        = string
    default     = "Standard"
}

variable "replication_type"{
    description = "Data replication strategy: LRS, GRS, ZRS, etc."
    type        = string
    default     = "LRS"
}

variable "container_name"{
    description = "Name of the blob container created inside the storage account"
    type        =  string
    default     =  "privatedata"
}