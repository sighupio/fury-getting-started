<!-- BEGIN_TF_DOCS -->

# OVHcloud Managed Kubernetes using private network example module

This module purpose is to show how to simply Managedte a Managed Kubernetes cluster connected to a private network on OVHcloud.

## Inputs

| Name | Description | Default | Required |
|------|-------------|---------|:--------:|
| kube | Managed Kubernetes Cluster parameters | n/a | yes |
| pool | Node Pool parameters | n/a | yes |
| region | Region | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| kubeconfig\_file | kubeconfig file |

## Providers

| Name | Version |
|------|---------|
| openstack | ~> 1.49.0 |
| ovh | ~> 0.25.0 |

## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 1.3.6 |
| openstack | ~> 1.49.0 |
| ovh | ~> 0.25.0 |

## Resources

| Name | Type |
|------|------|
| [ovh_cloud_project_kube.kube](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/cloud_project_kube) | resource |
| [ovh_cloud_project_kube_nodepool.my_pool](https://registry.terraform.io/providers/ovh/ovh/latest/docs/resources/cloud_project_kube_nodepool) | resource |
| [openstack_networking_network_v2.my_private_network](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/data-sources/networking_network_v2) | data source |
<!-- END_TF_DOCS -->