
//Outputs of the default hostname and helping import the azure static web app

output "default_hostname" {
    description = "the auto-generated *.azurestaticapps.net hostname"
    value       = azurerm_static_web_app.main.default_host_name
}


output "static_site_id" {
    description = "Resource ID of the Static Web App"
    value       =  azurerm_static_web_app.main.id
}


