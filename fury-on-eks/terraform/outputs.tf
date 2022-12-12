output "velero_patch" {
  description = "Velero Kustomize patches for deployment"
  value       = module.velero.deployment
  sensitive   = true
}

output "velero_service_account_patch" {
  description = "Velero Service Account patches"
  value = module.velero.service_account
  sensitive = true
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

output "ebs_csi_driver_patches" {
  description = "EBS CSI Driver Kustomize patches"
  value = module.ebs_csi_driver_iam_role.ebs_csi_driver_patches
  sensitive = true
}