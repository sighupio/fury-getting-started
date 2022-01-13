terraform {
#   backend "s3" {
#     bucket: <S3_BUCKET>
#     key: <MY_KEY> 
#     region: <S3_BUCKET_REGION>
#   }
  required_version = ">= 0.12"

  required_providers {
    aws        = "=3.37.0"
  }
}

provider "aws" {
  region = "eu-west-1"
}

module "velero" {
  source             = "../vendor/modules/dr/eks-velero"
  backup_bucket_name = "fury-eks-demo-velero"
  oidc_provider_url  = "oidc.eks.eu-west-1.amazonaws.com/id/CDB7AE563FA0B5CFA190CCDF0425A987"

}
