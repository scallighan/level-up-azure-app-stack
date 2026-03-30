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

resource "azurerm_container_app" "bot" {
  name                         = "aca-bot-${local.func_name}"
  container_app_environment_id = data.azurerm_container_app_environment.this.id
  resource_group_name          = data.azurerm_resource_group.this.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "bot"
      image  = "ghcr.io/${var.gh_repo}-bot:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name = "RUNNING_ON_AZURE"
        value = "1"
      }

      env {
        name = "TENANT_ID"
        value = data.azurerm_client_config.current.tenant_id
      }

      env {
        name = "CLIENT_ID"
        value = azurerm_user_assigned_identity.bot.client_id
      }
      env {
        name = "tenantId"
        value = data.azurerm_client_config.current.tenant_id
      }

      env {
        name = "clientId"
        value = azurerm_user_assigned_identity.bot.client_id
      }

      env {
        name = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.bot.client_id
      }

      # new for M365 Agent SDK
      env {
        name = "CONNECTIONS__SERVICE_CONNECTION__SETTINGS__TENANTID"
        value = data.azurerm_client_config.current.tenant_id
      }
      env {
        name = "CONNECTIONS__SERVICE_CONNECTION__SETTINGS__CLIENTID"
        value = azurerm_user_assigned_identity.bot.client_id
      }
      env {
        name = "CONNECTIONS__SERVICE_CONNECTION__SETTINGS__AUTHTYPE"
        value = "UserManagedIdentity"
      }

      env {
        name = "AZURE_AI_PROJECT_ENDPOINT"
        value = "https://aif${local.func_name}.services.ai.azure.com/api/projects/fp${local.func_name}"
      }

      env {
        name = "FOUNDRY_MODEL"
        value = "gpt-5-mini"
      }

    }
    http_scale_rule {
      name                = "http-1"
      concurrent_requests = "100"
    }
    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 3978
    transport                  = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.bot.id]
  }
  tags = local.tags

  lifecycle {
    ignore_changes = [ secret ]
  }
}

resource "azurerm_user_assigned_identity" "bot" {
  location            = data.azurerm_resource_group.this.location
  name                = "uai-bot-${local.func_name}"
  resource_group_name = data.azurerm_resource_group.this.name
}

resource "azurerm_bot_service_azure_bot" "teamsbot" {
  name                = "bot-${local.func_name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = "global"
  microsoft_app_id    = azurerm_user_assigned_identity.bot.client_id
  sku                 = "F0"
  endpoint            = "https://${azurerm_container_app.bot.ingress[0].fqdn}/api/messages"
  microsoft_app_msi_id = azurerm_user_assigned_identity.bot.id
  microsoft_app_tenant_id = data.azurerm_client_config.current.tenant_id
  microsoft_app_type  = "UserAssignedMSI"
  tags = local.tags
}

resource "azurerm_bot_channel_ms_teams" "teams" {
  bot_name            = azurerm_bot_service_azure_bot.teamsbot.name
  location            = azurerm_bot_service_azure_bot.teamsbot.location
  resource_group_name = data.azurerm_resource_group.this.name
}

# give the bot identity access to foundry with Azure AI User role
resource "azurerm_role_assignment" "bot_foundry_access" {
  scope                = data.azurerm_resource_group.this.id
  role_definition_name = "Azure AI User"
  principal_id         = azurerm_user_assigned_identity.bot.principal_id
}