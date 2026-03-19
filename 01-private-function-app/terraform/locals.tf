locals {
  func_name      = var.func_name
  loc_for_naming = lower(replace(var.location, " ", ""))
  loc_short      = upper("${substr(local.loc_for_naming, 0, 1)}${trimprefix(trimprefix(local.loc_for_naming, "east"), "west")}")
  gh_repo        = split("/", var.gh_repo)[1]
  tags = {
    "managed_by" = "terraform"
    "repo"       = local.gh_repo
    "lab"        = "01-private-function-app"
  }
}

resource "azurerm_subnet" "function" {
  name                 = "snet-function-${local.func_name}-${local.loc_for_naming}"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = data.azurerm_virtual_network.this.name
  address_prefixes     = ["172.21.4.0/24"] #TODO Make this dynamic

  delegation {
    name = "Microsoft.App/environments"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_user_assigned_identity" "function" {
  name                = "uai-function-${local.func_name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
}

resource "azurerm_role_assignment" "function_storage_blob_data_contributor" {
  scope                = data.azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.function.principal_id
}

resource "azurerm_service_plan" "this" {
  name                = "asp-${local.func_name}}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  sku_name            = "FC1"
  os_type             = "Linux"
}

resource "azurerm_function_app_flex_consumption" "example" {
  name                = "func-${local.func_name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  service_plan_id     = azurerm_service_plan.this.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${data.azurerm_storage_account.this.primary_blob_endpoint}${azurerm_storage_container.example.name}"
  storage_authentication_type = "UserAssignedIdentity"
  storage_user_assigned_identity_id = azurerm_user_assigned_identity.function.id
  runtime_name                = "python"
  runtime_version             = "3.12"
  maximum_instance_count      = 50
  instance_memory_in_mb       = 2048

  site_config {}

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.function.id
    ]
  }
}

