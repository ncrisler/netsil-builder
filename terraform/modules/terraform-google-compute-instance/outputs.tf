#output "addresses" {
#  value = "${join(",", google_compute_address.instances.*.address)}"
#}
output "instance_ips" {
  value = "${join(" ", google_compute_instance.instances.*.network_interface.0.access_config.0.assigned_nat_ip)}"
}
