variable "region" {}

variable "amount" {}
variable "name_prefix" {}
variable "machine_type" {}
#variable "user_data" {}

variable "target_tags" {
  type    = "list"
  default = []
}

variable "resource_key" {
  default = "alpha"
}

variable "ssh_user" {
  default = "ubuntu"
}

variable "private_key_path" {
  default = "~/.ssh/netsil-dev.pem"
}

variable "public_key_path" {
  default = "~/.ssh/netsil-dev.pub"
}

variable "disk_type" {
  default = "pd-ssd"
}

variable "disk_size" {}
variable "disk_image" {}

variable "disk_create_local_exec_command_or_fail" {
  default = ":"
}

variable "disk_create_local_exec_command_and_continue" {
  default = ":"
}

variable "disk_destroy_local_exec_command_or_fail" {
  default = ":"
}

variable "disk_destroy_local_exec_command_and_continue" {
  default = ":"
}
