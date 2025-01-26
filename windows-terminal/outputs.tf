output "public_ip" {
  description = "Public IP address of the VM"
  value       = module.virtual_machine.vm_public_ip
}

output "vm_name" {
  description = "Name of the Virtual Machine"
  value       = module.virtual_machine.vm_name
}

output "vm_secret_username" {
  description = "Name of the secret for the username"
  value       = module.virtual_machine.vm_secret_username
}

output "vm_secret_password" {
  description = "Name of the secret for the password"
  value       = module.virtual_machine.vm_secret_password
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.resource_group.name
} 

output "key_vault_name" {
  description = "Name of the key vault"
  value       = module.keyvault.key_vault_name
}
