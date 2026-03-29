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


resource "random_password" "password" {
  length           = 16
  special          = false
}

resource "azurerm_key_vault_secret" "apikey" {
  depends_on = [ azurerm_role_assignment.kv_officer, azurerm_role_assignment.kv_cert_officer ]
  name         = "MCP-API-KEY"
  value        = random_password.password.result
  key_vault_id = data.azurerm_key_vault.this.id
}


resource "azurerm_container_app" "mcp" {
  name                         = "aca-${local.func_name}-yfinance-mcp"
  container_app_environment_id = data.azurerm_container_app_environment.this.id
  resource_group_name          = data.azurerm_resource_group.this.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "mcp"
      image  = "ghcr.io/${var.gh_repo}-yfinance-mcp:latest"
      cpu    = 0.5
      memory = "1.0Gi"

      env {
        name = "MCP_API_KEY"
        secret_name = "mcp-api-key"
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
    target_port                = 8000
    transport                  = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name = "mcp-api-key"
    identity = data.azurerm_user_assigned_identity.this.id
    key_vault_secret_id = azurerm_key_vault_secret.apikey.id
  }

  identity {
    type = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.this.id]
  }
  tags = local.tags

  lifecycle {
    ignore_changes = [ secret ]
  }
}