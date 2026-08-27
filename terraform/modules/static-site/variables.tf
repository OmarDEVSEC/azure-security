//Create variabels for Azure static web app

variable "resource_group_name" {
    description =       "Resource group static web app belongs to"
    type        =        string
}

variable "location" {
    description =        "Azure region where the static web app lives"
    type        =         string
}

variable "site_name"{
    description =        "Name of the static web app resource in Azure"
    type        =         string
}


variable "sku_tier"{
    description =         "Pricing tier for the static web app Free or Premium"
    type        =          string
    default     =          "Free"
}