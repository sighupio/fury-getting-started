# Create

bucket-create:
	gsutil mb gs://fury-gcp-demo
	gsutil versioning set on gs://fury-gcp-demo

bootstrap-init:
	furyctl bootstrap init --reset

bootstrap-plan:
	furyctl bootstrap apply --dry-run

bootstrap-apply:
	furyctl bootstrap apply

cluster-init:
	furyctl cluster init --reset

cluster-plan:
	furyctl cluster apply --dry-run

cluster-apply:
	furyctl cluster apply

# Destroy

cluster-destroy:
	furyctl cluster destroy

bootstrap-destroy:
	furyctl bootstrap destroy

bucket-remove:
	gsutil rm -r gs://fury-gcp-demo/terraform
	gsutil rb gs://fury-gcp-demo