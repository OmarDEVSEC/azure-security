# Terrform inital provider code to connect to Azure

terraform {
    required_providers{
        azurerm = {
            source = "hashicorp/azurerm"
            version = "~> 3.0"
        }
    }
}

provider "azurerm" {
    features {}
}