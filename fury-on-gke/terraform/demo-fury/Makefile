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
	terraform output -raw velero_backup_storage_location > ../../manifests/demo-fury/resources/velero-backup-storage-location.yml
	terraform output -raw velero_volume_snapshot_location > ../../manifests/demo-fury/resources/velero-volume-snapshot-location.yml
	terraform output -raw velero_cloud_credentials > ../../manifests/demo-fury/resources/velero-cloud-credentials.yml
