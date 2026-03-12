output "ai_search_endpoint" {
  value = azapi_resource.ai_search.name
}

output "storage_account_resource_id"{
    value = azurerm_storage_account.this.id
}