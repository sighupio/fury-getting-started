FIREWALL_RULE_NAME = allow-nginx-ingress-admission-webhook
SOURCE_RANGE = 10.0.0.0/28
PROJECT = your-project-id
NETWORK = your-network-name
TAG = your-cluster-tag

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

create-firewall-rule:
	gcloud compute firewall-rules create $(FIREWALL_RULE_NAME) \
	--description="Allow request from API server to worker nodes for NGINX Ingress Validating Admission Webhook" \
	--allow=tcp:$(PORT) \
	--direction=INGRESS \
	--source-ranges="$(SOURCE_RANGE)" \
	--project="$(PROJECT)" \
	--network="$(NETWORK)" \
	--target-tags="$(TAG)"

delete-firewall-rule:
    gcloud compute firewall-rules delete $(FIREWALL_RULE_NAME)