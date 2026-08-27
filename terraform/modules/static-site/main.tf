//Create resource and set varibale to the resource for Azure static web app

resource "azurerm_static_web_app" "main"{
    name                   =           var.site_name
    resource_group_name    =           var.resource_group_name
    location               =           var.location
    sku_tier               =           var.sku_tier
    sku_size               =           var.sku_tier

    tags = {
        PersonalSite = "1"
    }

}

