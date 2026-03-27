# output function url
output "function_url" {
  value = azurerm_function_app_flex_consumption.this.default_hostname
}

# output sql server name and database name
output "sql_server_name" {
  value = azurerm_mssql_server.this.name
}  
output "sql_database_name" {
  value = azurerm_mssql_database.this.name
}

output "bacpac_storage_uri" {
  value = azurerm_storage_blob.bacpac.url
}

output "this_managed_identity_id" {
  value = data.azurerm_user_assigned_identity.this.id
}