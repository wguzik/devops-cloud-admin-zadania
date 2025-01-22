output "public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "vm_name" {
  description = "Name of the Virtual Machine"
  value       = azurerm_windows_virtual_machine.vm.name
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
} 