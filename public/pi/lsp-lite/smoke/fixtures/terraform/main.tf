terraform {
  required_version = ">= 1.0.0"
}

variable "name" {
  type = string
}

output "o" {
  value = var.missing
}
