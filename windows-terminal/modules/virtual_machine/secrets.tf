resource "random_password" "vm_password" {
  length           = 16
  special          = true
  override_special = "!@#$%"
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
}

resource "azurerm_key_vault_secret" "vm_password" {
  name         = "${var.vm_name}-admin-password"
  value        = random_password.vm_password.result
  key_vault_id = var.key_vault_id
} 

resource "azurerm_key_vault_secret" "vm_username" {
  name         = "${var.vm_name}-admin-username"
  value        = var.admin_username
  key_vault_id = var.key_vault_id
} 
