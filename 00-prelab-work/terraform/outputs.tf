output "container_app_name" {
	description = "The name of the Azure Container App."
	value       = azurerm_container_app.this.name
}

output "resource_group_name" {
	description = "The name of the Resource Group."
	value       = azurerm_resource_group.this.name
}

output "containerapp_exec_command" {
	description = "az CLI command to exec into the container app."
	value       = "az containerapp exec -n ${azurerm_container_app.this.name} -g ${azurerm_resource_group.this.name} --command /bin/bash"
}
