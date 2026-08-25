# Terrform inital provider code to connect to Azure
#plugin that translates Terraform's
# generic language into actual Azure API calls. azurerm is HashiCorp's
# official Azure provider

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

