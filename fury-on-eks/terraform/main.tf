terraform {
#   backend "s3" {
#     bucket: <S3_BUCKET>
#     key: <MY_KEY> 
#     region: <S3_BUCKET_REGION>
#   }
  required_version = ">= 0.12"

  required_providers {
    aws        = "=2.70.0"
  }
}

provider "aws" {
  region = "eu-west-1"
}

module "velero" {
  source             = "../../vendor/modules/dr/eks-velero"
  name               = "demo-fury"
  env                = "demo"
  backup_bucket_name = "demo-fury-velero"
  oidc_provider_url  = "oidc.eks.eu-west-1.amazonaws.com/id/B04477AFC754650E08D8E46730715193"
  region             = "eu-west-1"

}
