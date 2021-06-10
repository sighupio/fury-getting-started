output "velero_backup_storage_location" {
  value = module.velero.backup_storage_location
  sensitive = true
}

output "velero_cloud_credentials" {
  value = module.velero.cloud_credentials
  sensitive = true
}

output "velero_volume_snapshot_location" {
  value = module.velero.volume_snapshot_location
  sensitive = true
}