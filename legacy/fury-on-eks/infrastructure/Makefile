# Create

bucket-create:
	aws s3api create-bucket --bucket fcp-eks-demo --region eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1

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
	aws s3api delete-object --bucket fcp-eks-demo --key terraform/bootstrap
	aws s3api delete-object --bucket fcp-eks-demo --key terraform/cluster
	aws s3api delete-object --bucket fcp-eks-demo --key terraform/velero
	aws s3api delete-bucket --bucket fcp-eks-demo