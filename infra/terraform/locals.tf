locals {
  prefix      = "ilminate-${var.service_name}"
  tags_common = { Project = "Ilminate", Service = var.service_name }
}

