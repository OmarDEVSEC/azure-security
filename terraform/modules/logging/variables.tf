# Creating a logging module for diagnostics

variable "resource_group_name"{
    description = "Resource group for the Log Analytics workspace"
    type        = string
}

variable "location" {
    description = "Azure region for the workspace"
    type        = string
}

variable "workspace_name"{
    description = "Name of the log analytics workspace"
    type        = string
}

// SKU = PerGB2018 is the standard pay as you go pricing model for log analytics
variable "sku"{
    description = "Pricing tier for the workspace"
    type        =  string
    default     =  "PerGB2018"
}



variable "retention_in_days"{
    description = "How long the logs will be retained, in days"
    type        = number
    default     = 30
}
