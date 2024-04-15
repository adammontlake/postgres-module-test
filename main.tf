# resource azurerm_resource_group "rg" {
#   name     = "target-db"
#   location = "East US"
# }

data azurerm_resource_group "rg" {
  name = "Nevada-migration-test"
}

data azurerm_virtual_network "vnet" {
  name                = "adam-test-vnet"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data azurerm_subnet "subnet" {
  name                 = "default"
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

resource "random_password" "admin_password" {
  special = "false"
  length  = 32
}

resource azurerm_private_dns_zone "private_dns_zone" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name
}

module "postgresql_flexible" {
  source  = "./Module/postgres"
  #version = "7.3.0"

  location       = data.azurerm_resource_group.rg.location
  location_short = "gw"
  environment    = "development"
  stack          = "Nevada"
  client_name    = "nuvei"
  resource_group_name = data.azurerm_resource_group.rg.name

  tier               = "GeneralPurpose"
  size               = "D2s_v3"
  storage_mb         = 32768
  postgresql_version = 16

  allowed_cidrs = {
    "1" = "10.0.0.0/24"
    "2" = "77.126.4.46/32"
  }

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  administrator_login    = "azureadmin"
  administrator_password = random_password.admin_password.result

  databases = {
    mydatabase = {
      collation = "en_US.utf8"
      charset   = "UTF8"
    }
  }

  maintenance_window = {
    day_of_week  = 3
    start_hour   = 3
    start_minute = 0
  }

  logs_destinations_ids = [
    "84bf7ac7-12d2-4d55-b775-5ea1c9df4a79"
  ]

  delegated_subnet_id = data.azurerm_subnet.subnet.id
  private_dns_zone_id = azurerm_private_dns_zone.private_dns_zone.id

  # extra_tags = {
  #   foo = "bar"
  # }
}

# provider "postgresql" {
#   host      = module.postgresql_flexible.postgresql_flexible_fqdn
#   port      = 5432
#   username  = module.postgresql_flexible.postgresql_flexible_administrator_login
#   password  = module.postgresql_flexible.postgresql_flexible_administrator_password
#   sslmode   = "require"
#   superuser = false
# }

# module "postgresql_users" {
#   source  = "claranet/users/postgresql"
#   version = "x.x.x"

#   for_each = module.postgresql_flexible.postgresql_flexible_databases_names

#   administrator_login = module.postgresql_flexible.postgresql_flexible_administrator_login

#   database = each.key
# }

# module "postgresql_configuration" {
#   source  = "claranet/database-configuration/postgresql"
#   version = "x.x.x"

#   for_each = module.postgresql_flexible.postgresql_flexible_databases_names

#   administrator_login = module.postgresql_flexible.postgresql_flexible_administrator_login

#   database_admin_user = module.postgresql_users[each.key].user
#   database            = each.key
#   schema_name         = each.key
# }