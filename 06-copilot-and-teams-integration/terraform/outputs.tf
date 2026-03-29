output "bot_endpoint" {
  value = azurerm_container_app.bot.ingress[0].fqdn
}

output "bot_app_id" {
  value = azurerm_user_assigned_identity.bot.client_id
}