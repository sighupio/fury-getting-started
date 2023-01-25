<!-- BEGIN_TF_DOCS -->

# OVHcloud Managed Kubernetes on private network example

This example create and deploy a private network environment on OVHcloud Public Cloud, and then create and deploy a Managed Kubernetes cluster.

## Inputs

| Name | Description | Default | Required |
|------|-------------|---------|:--------:|
| kube | Managed Kubernetes Cluster parameters | n/a | yes |
| network | Private Network Parameters | n/a | yes |
| pool | Node Pool parameters | n/a | yes |
| region | Region | n/a | yes |
| router | Router Parameters | n/a | yes |
| subnet | Subnet parameters | n/a | yes |

## Outputs

No outputs.

## Providers

| Name | Version |
|------|---------|
| local | ~> 2.2.3 |

## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 1.3.6 |
| local | ~> 2.2.3 |

## Resources

| Name | Type |
|------|------|
| [local_file.kubeconfig_file](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
<!-- END_TF_DOCS -->