resource "random_string" "id" {
  length           = 6
  special          = false
}

locals {
  rg_name = "${var.prefix}-rg-${random_string.id.result}"
  vm_name = substr("${var.prefix}-vm-${random_string.id.result}", 0, 15)
  kv_name = "${var.prefix}-kv-${random_string.id.result}"
}