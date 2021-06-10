output "velero_patch" {
  description = "Velero Kustomize patches"
  value       = module.velero.kubernetes_patches
  sensitive   = true
}

output "velero_backup_storage_location" {
  description = "Velero BackupStorageLocation CRD"
  value       = module.velero.backup_storage_location
  sensitive   = true
}

output "velero_volume_snapshot_location" {
  description = "Velero VolumeSnapshotLocation CRD"
  value       = module.velero.volume_snapshot_location
  sensitive   = true
}