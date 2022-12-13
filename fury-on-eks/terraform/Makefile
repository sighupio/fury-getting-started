init:
	terraform init

plan:
	terraform plan -out terraform.plan

apply:
	terraform apply terraform.plan

destroy:
	terraform destroy

output:
	terraform output

generate-output:
	terraform output -raw velero_patch > ../manifests/dr/patches/velero.yml
	terraform output -raw velero_service_account_patch > ../manifests/dr/patches/velero-service-account.yml
	terraform output -raw velero_backup_storage_location > ../manifests/dr/resources/velero-backup-storage-location.yml
	terraform output -raw velero_volume_snapshot_location > ../manifests/dr/resources/velero-volume-snapshot-location.yml
	terraform output -raw ebs_csi_driver_patches > ../manifests/aws/patches/ebs-csi-driver.yml
