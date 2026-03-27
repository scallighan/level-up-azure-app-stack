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