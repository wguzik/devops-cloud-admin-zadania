output "vm_name" {
  value = azurerm_windows_virtual_machine.vm.name
}

output "vm_public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "vm_secret_username" {
  value = azurerm_key_vault_secret.vm_username.name
}

output "vm_secret_password" {
  value = azurerm_key_vault_secret.vm_password.name
}
