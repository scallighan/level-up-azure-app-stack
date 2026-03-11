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

data "azurerm_subnet" "pe" {
  name                 = "snet-pe-${var.func_name}-${local.loc_for_naming}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.this.name
}