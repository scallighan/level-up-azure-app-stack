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
    storage {
      data_plane_available = false
    }
  }

  subscription_id = var.subscription_id
}

resource "azurerm_subnet" "foundry" {
  name                 = "snet-foundry-${local.func_name}-${local.loc_for_naming}"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = data.azurerm_virtual_network.this.name
  address_prefixes     = ["172.21.3.0/24"] #TODO Make this dynamic

  delegation {
    name = "Microsoft.App/environments"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}


## Standard Foundry Resources

resource "azurerm_storage_account" "this" {
  name = "saaif${local.func_name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location = data.azurerm_resource_group.this.location

  account_kind = "StorageV2"
  account_tier = "Standard"
  account_replication_type = "LRS"

  shared_access_key_enabled = false

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  network_rules {
    default_action = "Deny"
    bypass = [
      "AzureServices"
    ]
  }
  
  tags = local.tags
}

resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = "cdb${local.func_name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location = data.azurerm_resource_group.this.location

  offer_type        = "Standard"
  kind              = "GlobalDocumentDB"
  free_tier_enabled = false

  local_authentication_disabled = true
  public_network_access_enabled = false

  automatic_failover_enabled       = false
  multiple_write_locations_enabled = false

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = data.azurerm_resource_group.this.location
    failover_priority = 0
    zone_redundant    = false
  }
}

resource "azapi_resource" "ai_search" {
  type                      = "Microsoft.Search/searchServices@2025-05-01"
  name                      = "ais${local.func_name}"
  parent_id                 = data.azurerm_resource_group.this.id
  location                  = data.azurerm_resource_group.this.location
  schema_validation_enabled = true

  body = {
    sku = {
      name = "basic"
    }

    identity = {
      type = "SystemAssigned"
    }

    properties = {

      replicaCount   = 1
      partitionCount = 1
      hostingMode    = "default"
      semanticSearch = "disabled"

      disableLocalAuth = false
      authOptions = {
        aadOrApiKey = {
          aadAuthFailureMode = "http401WithBearerChallenge"
        }
      }

      publicNetworkAccess = "Disabled"
      networkRuleSet = {
        bypass = "None"
      }
    }
  }
}

resource "azapi_resource" "ai_foundry" {
  type                      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name                      = "aif${local.func_name}"
  parent_id                 = data.azurerm_resource_group.this.id
  location                  = data.azurerm_resource_group.this.location
  schema_validation_enabled = false

  body = {
    kind = "AIServices",
    sku = {
      name = "S0"
    }
    identity = {
      type = "SystemAssigned"
    }

    properties = {
      disableLocalAuth = false

      allowProjectManagement = true

      customSubDomainName = "aif${local.func_name}"

      publicNetworkAccess = "Disabled"
      networkAcls = {
        defaultAction = "Allow"
      }

      # Enable VNet injection for Standard Agents
      networkInjections = [
        {
          scenario                   = "agent"
          subnetArmId                = azurerm_subnet.foundry.id
          useMicrosoftManagedNetwork = false
        }
      ]
    }
  }
}

resource "azurerm_private_endpoint" "pe_storage" {
  depends_on = [
    azurerm_storage_account.this
  ]

  name                = "${azurerm_storage_account.this.name}-private-endpoint"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id           = data.azurerm_subnet.pe.id
  private_service_connection {
    name                           = "${azurerm_storage_account.this.name}-private-link-service-connection"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names = [
      "blob"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azurerm_storage_account.this.name}-dns-config"
    private_dns_zone_ids = [
      data.azurerm_private_dns_zone.blob.id
    ]
  }
}

resource "azurerm_private_endpoint" "pe_cosmosdb" {
  depends_on = [
    azurerm_private_endpoint.pe_storage,
    azurerm_cosmosdb_account.cosmosdb
  ]

  name                = "${azurerm_cosmosdb_account.cosmosdb.name}-private-endpoint"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id           = data.azurerm_subnet.pe.id

  private_service_connection {
    name                           = "${azurerm_cosmosdb_account.cosmosdb.name}-private-link-service-connection"
    private_connection_resource_id = azurerm_cosmosdb_account.cosmosdb.id
    subresource_names = [
      "Sql"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azurerm_cosmosdb_account.cosmosdb.name}-dns-config"
    private_dns_zone_ids = [
      data.azurerm_private_dns_zone.cosmosdb.id
    ]
  }
}

resource "azurerm_private_endpoint" "pe_aisearch" {
  depends_on = [
    azurerm_private_endpoint.pe_cosmosdb,
    azapi_resource.ai_search
  ]

  name                = "${azapi_resource.ai_search.name}-private-endpoint"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id           = data.azurerm_subnet.pe.id

  private_service_connection {
    name                           = "${azapi_resource.ai_search.name}-private-link-service-connection"
    private_connection_resource_id = azapi_resource.ai_search.id
    subresource_names = [
      "searchService"
    ]
    is_manual_connection = false
  }

  private_dns_zone_group {
    name = "${azapi_resource.ai_search.name}-dns-config"
    private_dns_zone_ids = [
      data.azurerm_private_dns_zone.search.id
    ]
  }
}