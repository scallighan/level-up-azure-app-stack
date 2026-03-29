data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "this" {
  name                = "vnet-${var.func_name}-${local.loc_for_naming}"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "cosmosdb" {
  name                = "privatelink.documents.azure.com"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "search" {
  name                = "privatelink.search.windows.net"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "cognitiveservices" {
  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "servicesai" {
  name                = "privatelink.services.ai.azure.com"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "openai" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "azurewebsites" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.resource_group_name
}

data "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "pe" {
  name                 = "snet-pe-${var.func_name}-${local.loc_for_naming}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.this.name
}

data "azurerm_client_config" "current" {}

data "azurerm_storage_account" "this" {
  name                = "sa${local.func_name}"
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_key_vault" "this" {
  name                = "kv-${local.func_name}"
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_user_assigned_identity" "this" {
  name                = "uai-${local.func_name}"
  resource_group_name = data.azurerm_resource_group.this.name
}

data "azurerm_application_insights" "this" {
  name                = "${local.func_name}-insights"
  resource_group_name = data.azurerm_resource_group.this.name
}