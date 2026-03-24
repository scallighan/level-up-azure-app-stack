variable "subscription_id" {
  type      = string
  sensitive = true
}

variable "location" {
  type    = string
}

variable "gh_repo" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "storage_account_name" {
  type = string
}

variable "container_name"{
  type = string
}

variable "key" {
  type = string
  default = "02-internal-apim.tfstate"
}

variable "func_name" {
  type = string
}