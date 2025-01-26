module "resource_group" {
  source   = "./modules/resource_group"
  rg_name  = local.rg_name
  prefix   = var.prefix
  location = var.location
}

module "keyvault" {
  source              = "./modules/keyvault"
  prefix              = var.prefix
  kv_name             = local.kv_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
}

module "vnet" {
  source              = "./modules/vnet"
  prefix              = var.prefix
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
}

module "virtual_machine" {
  source              = "./modules/virtual_machine"
  prefix              = var.prefix
  location            = module.resource_group.location
  vm_name             = local.vm_name
  admin_username      = var.admin_username

  resource_group_name = module.resource_group.name
  subnet_id           = module.vnet.subnet_id
  key_vault_id        = module.keyvault.key_vault_id
}