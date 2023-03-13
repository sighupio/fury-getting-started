<!-- BEGIN_TF_DOCS -->

# OVHcloud private network example module

This module purpose is to show how to simply create a private network, subnet and router on OVHcloud.

## Inputs

| Name | Description | Default | Required |
|------|-------------|---------|:--------:|
| network | Private Network Parameters | n/a | yes |
| region | Region | n/a | yes |
| router | Router Parameters | n/a | yes |
| subnet | Subnet parameters | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| ext\_net\_id | External Network Id |
| my\_private\_network\_id | Private Network Id |
| my\_subnet\_id | Subnet Id |

## Providers

| Name | Version |
|------|---------|
| openstack | ~> 1.49.0 |

## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 1.3.6 |
| openstack | ~> 1.49.0 |

## Resources

| Name | Type |
|------|------|
| [openstack_networking_network_v2.my_private_network](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_network_v2) | resource |
| [openstack_networking_router_interface_v2.my_router_interface](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_router_interface_v2) | resource |
| [openstack_networking_router_v2.my_router](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_router_v2) | resource |
| [openstack_networking_subnet_v2.my_subnet](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_subnet_v2) | resource |
| [openstack_networking_network_v2.ext_net](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/data-sources/networking_network_v2) | data source |
<!-- END_TF_DOCS -->