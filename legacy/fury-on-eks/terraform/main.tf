terraform {
  # backend "s3" {
  #   bucket = "fury-demo-eks"
  #   key    = "fury/distribution"
  #   region = "eu-west-1"
  # }
  required_version = ">= 0.15.4"

  required_providers {
    aws = "=3.37.0"
  }
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "velero_bucket_name" {
  description = "Velero bucket name"
  type        = string
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

provider "aws" {
  region = "eu-west-1"
}

module "velero" {
  source             = "../vendor/modules/dr/aws-velero"
  backup_bucket_name = var.velero_bucket_name
  oidc_provider_url  = replace(data.aws_eks_cluster.this.identity.0.oidc.0.issuer, "https://", "")
}

module "ebs_csi_driver_iam_role" {
  source       = "../vendor/modules/aws/iam-for-ebs-csi-driver"
  cluster_name = var.cluster_name
}
