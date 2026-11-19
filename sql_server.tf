resource "azurerm_mssql_server" "sql_01" {
  name                          = var.sql_server_name
  resource_group_name           = azurerm_resource_group.rg_01.name
  location                      = var.sql_location
  version                       = "12.0"
  administrator_login           = var.sql_admin_username
  administrator_login_password  = var.sql_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = true
  tags                          = var.tags
}

resource "azurerm_mssql_database" "sql_01" {
  name        = var.sql_database_name
  server_id   = azurerm_mssql_server.sql_01.id
  sku_name    = "Basic"
  max_size_gb = 2
  tags        = var.tags
}

resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql_01.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
