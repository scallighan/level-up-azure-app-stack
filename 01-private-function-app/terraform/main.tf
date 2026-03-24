terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.52.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
    azapi = {
      source = "azure/azapi"
      version = "=2.7.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.6.0"
    }
  }
  backend "azurerm" {

  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  storage_use_azuread = true
  subscription_id = var.subscription_id
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

resource "azurerm_storage_container" "this" {
  name                  = "function"
  storage_account_id = data.azurerm_storage_account.this.id
  container_access_type = "private"
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
  name                = "asp-${local.func_name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  sku_name            = "FC1"
  os_type             = "Linux"

  tags = local.tags
}

resource "azurerm_function_app_flex_consumption" "this" {
  name                = "func-${local.func_name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  service_plan_id     = azurerm_service_plan.this.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${data.azurerm_storage_account.this.primary_blob_endpoint}${azurerm_storage_container.this.name}"
  storage_authentication_type = "UserAssignedIdentity"
  storage_user_assigned_identity_id = azurerm_user_assigned_identity.function.id
  runtime_name                = "python"
  runtime_version             = "3.12"
  maximum_instance_count      = 50
  instance_memory_in_mb       = 2048

  virtual_network_subnet_id = azurerm_subnet.function.id

  webdeploy_publish_basic_authentication_enabled = false

  app_settings = {
    "AzureWebJobsStorage" = ""
    "AzureWebJobsStorage__blobServiceUri" = data.azurerm_storage_account.this.primary_blob_endpoint
    "AzureWebJobsStorage__clientId" = azurerm_user_assigned_identity.function.client_id
    "AzureWebJobsStorage__credential" = "ManagedIdentity"
    "AzureWebJobsStorage__queueServiceUri" = data.azurerm_storage_account.this.primary_queue_endpoint
    "AzureWebJobsStorage__tableServiceUri" = data.azurerm_storage_account.this.primary_table_endpoint
    "AZURE_CLIENT_ID" = azurerm_user_assigned_identity.function.client_id
    "STORAGE_ACCOUNT_NAME" = data.azurerm_storage_account.this.name

  }

  site_config {
     vnet_route_all_enabled = true
  }

  auth_settings_v2 {
      auth_enabled = true
      default_provider = "azureactivedirectory"
      excluded_paths = ["/www/HttpExample"]
      active_directory_v2 {
        client_id = data.azuread_application.jumpbox.client_id
        tenant_auth_endpoint = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0/"
      }
      login {
        
      }
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.function.id
    ]
  }

  tags = local.tags
}

data "archive_file" "function_zip"  {
  type        = "zip"
  source_dir  = "../func"
  output_path = "${path.module}/function.zip"
}

resource "null_resource" "deploy_function_code" {
  triggers = {
    index = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "az functionapp deployment source config-zip --name ${azurerm_function_app_flex_consumption.this.name} --resource-group ${data.azurerm_resource_group.this.name} --src ${data.archive_file.function_zip.output_path}"
  }

  depends_on = [azurerm_function_app_flex_consumption.this]
}

# create a holdings container and add the data/hodlings.csv file to it
resource "azurerm_storage_container" "holdings" {
  name                  = "holdings"
  storage_account_id = data.azurerm_storage_account.this.id
  container_access_type = "private"
} 

resource "azurerm_storage_blob" "holdings_csv" {
  name                   = "holdings.csv"
  storage_account_name  = data.azurerm_storage_account.this.name
  storage_container_name = azurerm_storage_container.holdings.name
  type                   = "Block"
  source                 = "./data/holdings.csv"
}