variable "log_analytics_workspace_id"{
    type = string
}
variable "storage_account_id"{
    type = string
}
variable "key_vault_id"{
    type = string
}

variable "nsg_id"{
    type = string
}

variable "enable_defender"{
    description = "Whether to enable Defender for Cloud (Standard tier) on VMs - this incurs cost, so its a toggle"
    type        = bool
    default     = false
}
