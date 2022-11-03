output "serviceName" {
 value = var.serviceName
}

output "public_ip" {
  value = var.IP
}

output "myPrivateNetwork" {
  value = tolist(ovh_cloud_project_network_private.myPrivateNetwork.regions_attributes)[0].openstackid
}
