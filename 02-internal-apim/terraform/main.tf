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

resource "azurerm_subnet" "apim" {
  name                 = "snet-apim-${local.func_name}-${local.loc_for_naming}"
  resource_group_name  = data.azurerm_resource_group.this.name
  virtual_network_name = data.azurerm_virtual_network.this.name
  address_prefixes     = ["172.21.5.0/24"]
}

# network security group for APIM
resource "azurerm_network_security_group" "apim" {
  name                = "nsg-apim-${local.func_name}-${local.loc_for_naming}"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
    security_rule {
        name                       = "Allow-APIM-Management"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3443"
        source_address_prefix      = "ApiManagement"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "AllowHTTPs"
        priority                   = 1000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_ranges    = ["443"]
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

}

# associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "apim" {
  subnet_id                 = azurerm_subnet.apim.id
  network_security_group_id = azurerm_network_security_group.apim.id
}

# apim private DNS zone
resource "azurerm_private_dns_zone" "apim" {
    name                = "azure-api.net"
    resource_group_name = data.azurerm_resource_group.this.name
}

# associate private DNS zone with virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "apim" {
    name                  = "link-apim-${local.func_name}-${local.loc_for_naming}"
    resource_group_name   = data.azurerm_resource_group.this.name
    private_dns_zone_name = azurerm_private_dns_zone.apim.name
    virtual_network_id    = data.azurerm_virtual_network.this.id
}

resource "azurerm_api_management" "apim" {
  name                 = "apim-${local.func_name}"
  location             = data.azurerm_resource_group.this.location
  resource_group_name  = data.azurerm_resource_group.this.name
  publisher_name       = "level-up-azure-app-stack"
  publisher_email      = "something@nothing.com"
  virtual_network_type = "Internal"
  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_user_assigned_identity.this.id
    ]
  }

  sku_name = "Developer_1"
  tags = local.tags
}

# enable diagnostic settings for APIM
resource "azurerm_monitor_diagnostic_setting" "apim" {
  name               = "diag-apim-${local.func_name}-${local.loc_for_naming}"
  target_resource_id = azurerm_api_management.apim.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "GatewayLogs"
  }

  enabled_log {
    category = "WebSocketConnectionLogs"
  }

  enabled_log {
    category = "DeveloperPortalAuditLogs"
  }

  enabled_log {
    category = "GatewayLlmLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }

}

# add APIM internal IP to private DNS zone
resource "azurerm_private_dns_a_record" "apim" {
  name                = azurerm_api_management.apim.name
  zone_name           = azurerm_private_dns_zone.apim.name
  resource_group_name = data.azurerm_resource_group.this.name
  ttl                 = 300
  records             = [azurerm_api_management.apim.private_ip_addresses[0]]
}

# add an Echo API to APIM for testing
resource "azurerm_api_management_api" "echo" {
  name                = "echo-api"
  resource_group_name = data.azurerm_resource_group.this.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Echo API"
  path                = "echo"
  protocols           = ["https"]
}

resource "azurerm_api_management_api_operation" "echo" {
  operation_id        = "echo"
  api_name            = azurerm_api_management_api.echo.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = data.azurerm_resource_group.this.name
  display_name        = "Echo"
  method              = "GET"
  url_template        = "/"
}

# add a policy to the Echo API to return the incoming request as the response
resource "azurerm_api_management_api_operation_policy" "echo" {
  api_name            = azurerm_api_management_api.echo.name
  operation_id        = azurerm_api_management_api_operation.echo.operation_id
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = data.azurerm_resource_group.this.name
  xml_content         = <<XML
<policies>
    <inbound>
        <base />
        <return-response>
            <set-status code="200" reason="OK" />
            <set-body>@{
                var headers = context.Request.Headers
                                .Where(h => h.Key != "A" && h.Key != "B" && h.Key != "C")
                                .Select(h => string.Format("{0}: {1}", h.Key, String.Join(", ", h.Value)))
                                .ToArray<string>(); 
                return String.Join(" ||| ", headers);
            }</set-body>
        </return-response>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
</policies>
XML

}


# add a Data Access API to APIM for testing
resource "azurerm_api_management_api" "dataaccess" {
  name                = "dataaccess-api"
  resource_group_name = data.azurerm_resource_group.this.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Data Access API"
  path                = "dataaccess"
  protocols           = ["https"]
  service_url         = "https://${data.azurerm_linux_function_app.this.default_hostname}"
}

resource "azurerm_api_management_api_operation" "hello" {
  operation_id        = "hello"
  api_name            = azurerm_api_management_api.dataaccess.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = data.azurerm_resource_group.this.name
  display_name        = "Say Hello"
  method              = "GET"
  url_template        = "/"
}

resource "azurerm_api_management_api_operation_policy" "hello" {
  api_name            = azurerm_api_management_api.dataaccess.name
  operation_id        = azurerm_api_management_api_operation.hello.operation_id
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = data.azurerm_resource_group.this.name
  xml_content         = <<XML
<policies>
    <inbound>
        <base />
        <rewrite-uri template="/www/HttpExample" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
</policies>
XML
}

