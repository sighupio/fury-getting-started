terraform {
  # backend "gcs" {
  #   bucket = "<GCS_BUCKET>"
  #   prefix = "terraform/velero"
  # }
  required_version = ">= 0.12"

  required_providers {
    google        = "=3.55.0"
  }
}

provider "google" {
  region      = "europe-west3"
}

module "velero" {
  source             = "../../vendor/modules/dr/gcp-velero"
  backup_bucket_name = "<YOUR_BACKUP_BUCKET_NAME>"
  project            = "<YOUR_GOOGLE_PROJECT_NAME>"
}
