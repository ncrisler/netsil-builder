data "google_compute_image" "ubuntu" {
  family  = "ubuntu-1604-lts"
  project = "ubuntu-os-cloud"
}

data "google_compute_image" "centos" {
  family  = "centos-7"
  project = "centos-cloud"
}

variable "image_type" {
  default = "ubuntu-1604-lts"
}

variable "resource_key" {
  default = "alpha"
}

variable "region" {
  default = "us-west1"
}

variable "disk_size" {
  default = "100"
}

variable "machine_type" {
  default = "n1-standard-8"
}

variable "ssh_user" {
  default = "ubuntu"
}

variable "ssh_key" {
  default = "netsil-dev"
}

module "gcp" {
  source = "../modules/terraform-google-compute-instance"
  amount       = 1
  region       = "${var.region}"
  ssh_user     = "${var.ssh_user}"
  public_key_path = "~/.ssh/${var.ssh_key}.pub"
  private_key_path = "~/.ssh/${var.ssh_key}.pem"
  name_prefix  = "gcp-${var.resource_key}"
  machine_type = "${var.machine_type}"
  disk_size    = "${var.disk_size}"
  disk_image   = "${var.image_type}"
}

