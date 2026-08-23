

// Monitoring variables

//Variables without default (resource_group_name, alert_email, 
// subscription_id) are required — the module call must supply them, or terraform plan errors immediately

variable "resource_group_name"{
    description = "Resource group this modules resources belong to"
    type        = string
}

variable "location"{
    description = "Azure region for resources"
    type        = string
    default     = "Central US"
}

variable "alert_email"{
    description = "Email address to recieve cost and service health alerts"
    type        = string
}

variable "monthly_budget_amount"{
    description = "Monthly budget threshold in USD"
    type        = number
    default     = 15
}

variable "subscription_id" {
    description = "Azure subscription ID"
    type        = strin
}