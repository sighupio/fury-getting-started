output "serviceName" {
 value = var.serviceName
}

output "public_ip" {
  value = var.IP
}

output "pvnw_apps" {
  value = tolist(ovh_cloud_project_network_private.myPrivateNetwork.regions_attributes)[0].openstackid
}

output "subnet_apps" {
  value = openstack_networking_subnet_v2.mySubnet.id
}

output "Ext-Net" {
  value = openstack_networking_network_v2.Ext-Net.id
}
