# Fury on OVHcloud

This step-by-step tutorial helps you deploy the **Kubernetes Fury Distribution** on a Managed Kubernetes cluster on OVHcloud.

This tutorial covers the following steps:

1. Download the latest version of Fury with `furyctl`.
2. Install Fury distribution.
3. Explore some features of the distribution.
4. Teardown the environment.

> ⚠️ OVHcloud **will charge you** to provision the resources used in this tutorial. You should be charged only a few dollars or euros, but we are not responsible for any charges that may incur.
>
> ❗️ **Remember to stop all the instances by following all the steps listed in the teardown phase.**
>
> 💻 If you prefer trying Fury in a local environment, check out the [Fury on Minikube][fury-on-minikube] tutorial.

## Prerequisites

This tutorial assumes some basic familiarity with Kubernetes and OVHcloud. Some experience with Terraform is helpful but not strictly required.

To follow this tutorial, you need:

1. A [OVHcloud Public Cloud](https://www.ovhcloud.com/en-gb/public-cloud) project in your OVHcloud account and a configured [vRack](https://docs.ovh.com/gb/en/publiccloud/network-services/public-cloud-vrack).

2. Packages that have to be installed into your environment for **OVHcloud Managed Kubernetes** bootstraping: 

- [terraform](https://developer.hashicorp.com/terraform/cli) cli.

- [openstack](https://docs.openstack.org/newton/user-guide/common/cli-install-openstack-command-line-clients.html) cli.

- [jq](https://stedolan.github.io/jq) command-line JSON processor.

3. Packages that have to be installed into your environment to install and manage your **Kubernetes Fury Distribution**:

- [furyctl](https://github.com/sighupio/furyctl) cli.

- [kubectl](https://kubernetes.io/fr/docs/tasks/tools/install-kubectl) cli.

4. Clone the [fury getting started repository][fury-gke-repository] containing all the example code used in this tutorial:

```bash
git clone https://github.com/sighupio/fury-getting-started
cd fury-getting-started/fury-on-ovhcloud
```

5. Setup your OVHcloud credentials by editing the **infrastructure/utils/ovhrc file**:

Create a new ovhrc from the ovhrc.templite file:

```bash
cp infrastructure/utils/ovhrc.template infrastructure/utils/ovhrc
```

Edit the file and fill the missing values.

The firt part of the config file is for the openstack client, which must be filled with informations from your [openstack user openrc file](https://docs.ovh.com/gb/en/public-cloud/creation-and-deletion-of-openstack-user):

```bash
# Openstack vars from openrc file
export OS_AUTH_URL=https://auth.cloud.ovh.net/v3
export OS_IDENTITY_API_VERSION=3
export OS_USER_DOMAIN_NAME=${OS_USER_DOMAIN_NAME:-"Default"}
export OS_PROJECT_DOMAIN_NAME=${OS_PROJECT_DOMAIN_NAME:-"Default"}
export OS_TENANT_ID=""
export OS_TENANT_NAME=""
export OS_USERNAME=""
export OS_PASSWORD=""
export OS_REGION_NAME="GRA7"
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi
```

The second part is for using the [OVHcloud API](https://api.ovh.com), create or use an existing [OVHcloud API token](https://www.ovh.com/auth/api/createToken) 

```bash
# OVH API vars from OVHcloud manager
export OVH_ENDPOINT=ovh-eu
export OVH_APPLICATION_KEY=
export OVH_APPLICATION_SECRET=
export OVH_CONSUMER_KEY=
```

The last part is needed by the terraform cli:

```bash
# Terraform
export TF_VAR_IP="$(curl -s ifconfig.me)/32"
export TF_VAR_serviceName="$OS_TENANT_ID"
export TF_VAR_keypairAdmin="" # The ready to deployed SSH public key
```

The **TF_VAR_IP** is setted with the machine where you are playing this tutorial public IP, if you want to use IP access restriction rules.

The **TF_VAR_serviceName** is for giving your openstack project Id to terraform.

The **TF_VAR_keypairAdmin** variable is optionnal and will only be used if you planned to acces Kubernetes Fury Distribution from a third Instance.

Initialize your environment with the needed variables:

```bash
. infrastructure/utils/ovhrc
```

## Step 1 - Automatic provisioning of the OVHcloud Managed Kubernetes Cluster





## Step 2 - Download fury modules

`furyctl` can do a lot more than deploying infrastructure. In this section, you use `furyctl` to download the monitoring, logging, and ingress modules of the Fury distribution.

### Inspect the Furyfile

`furyctl` needs a `Furyfile.yml` to know which modules to download.

For this tutorial, use the `Furyfile.yml`:

```yaml
versions:
  monitoring: v1.14.1
  logging: v1.10.2
  ingress: v1.12.2
#  dr: v1.9.2
#  opa: v1.6.2

bases:
  - name: monitoring/prometheus-operator
  - name: monitoring/prometheus-operated
  - name: monitoring/grafana
  - name: monitoring/goldpinger
  - name: monitoring/configs
  - name: monitoring/kubeadm-sm
  - name: monitoring/kube-proxy-metrics
  - name: monitoring/kube-state-metrics
  - name: monitoring/node-exporter
  - name: logging/elasticsearch-single
  - name: logging/cerebro
  - name: logging/curator
  - name: logging/fluentd
  - name: logging/kibana
  - name: ingress/nginx
  - name: ingress/forecastle
  - name: ingress/cert-manager
#  - name: dr/velero
#  - name: opa/gatekeeper

#modules:
#- name: dr/eks-velero
```

### Download Fury modules

1. Download the Fury modules with `furyctl`:

```bash
cd /demo/
furyctl vendor -H
```

2. Inspect the downloaded modules in the `vendor` folder:

```bash
tree -d /demo/vendor -L 3
```

Output:

```bash
$ tree -d vendor -L 3

vendor
└── katalog
    ├── ingress
    │   ├── cert-manager
    │   ├── forecastle
    │   └── nginx
    ├── logging
    │   ├── cerebro
    │   ├── curator
    │   ├── elasticsearch-single
    │   ├── fluentd
    │   └── kibana
    ├── monitoring
    │   ├── alertmanager-operated
    │   ├── configs
    │   ├── goldpinger
    │   ├── grafana
    │   ├── kube-proxy-metrics
    │   ├── kube-state-metrics
    │   ├── node-exporter
    │   ├── prometheus-operated
    │   └── prometheus-operator
    └── networking
        └── calico
```

## Step 3 - Installation

Each module is a Kustomize project. Kustomize allows to group together related Kubernetes resources and combine them to create more complex deployment. Moreover, it is flexible, and it enables a simple patching mechanism for additional customization.

To deploy the Fury distribution, use the main `manifests/demo-fury/kustomization.yaml` file:

```yaml
resources:
  
  # Monitoring
  - ../vendor/katalog/monitoring/prometheus-operator
  - ../vendor/katalog/monitoring/prometheus-operated
  - ../vendor/katalog/monitoring/grafana
  - ../vendor/katalog/monitoring/configs
  - ../vendor/katalog/monitoring/goldpinger
  - ../vendor/katalog/monitoring/kube-proxy-metrics
  - ../vendor/katalog/monitoring/kube-state-metrics
  - ../vendor/katalog/monitoring/node-exporter

  # Logging
  - ../vendor/katalog/logging/elasticsearch-single
  - ../vendor/katalog/logging/cerebro
  - ../vendor/katalog/logging/curator
  - ../vendor/katalog/logging/fluentd
  - ../vendor/katalog/logging/kibana

  # Ingress
  - ../vendor/katalog/ingress/nginx
  - ../vendor/katalog/ingress/forecastle
  - ../vendor/katalog/ingress/cert-manager

  # Ingress definitions
  - resources/ingress.yml

patchesStrategicMerge:

  - patches/prometheus-operated-resources.yml
  - patches/prometheus-operator-resources.yml
  - patches/grafana-resources.yml
  - patches/kibana-resources.yml
  - patches/elasticsearch-resources.yml
  - patches/fluentd-resources.yml
  - patches/fluentbit-resources.yml
  - patches/nginx-ingress-controller-resources.yml
```

This `kustomization.yaml`:

- references the modules downloaded in the previous sections
- patches the upstream modules (e.g. `patches/elasticsearch-resources.yml` limits the resources requested by elastic search)
- deploys some additional custom resources (e.g. `resources/ingress.yml`)

Install the modules:

```bash
cd /demo/manifests/

make apply
# Due to some chicken-egg 🐓🥚 problem with custom resources you have to apply again
make apply
```

## Step 4 - Explore the distribution

🚀 The distribution is finally deployed! In this section you explore some of its features.

### Setup local DNS

1. Get the address of the internal loadbalancer:

```bash
kubectl get svc ingress-nginx -n ingress-nginx --no-headers | awk '{print $4}'
```

Output:

```bash
10.1.0.5
```

3. Add the following line to your local `/etc/hosts`:

```bash
10.1.0.5 forecastle.fury.info cerebro.fury.info kibana.fury.info grafana.fury.info
```

Now, you can reach the ingresses directly from your browser.

### Forecastle

[Forecastle](https://github.com/stakater/Forecastle) is an open-source control panel where you can access all exposed applications running on Kubernetes.

Navigate to <http://forecastle.fury.info> to see all the other ingresses deployed, grouped by namespace.

![Forecastle][forecastle-screenshot]

### Kibana

[Kibana](https://github.com/elastic/kibana) is an open-source analytics and visualization platform for Elasticsearch. Kibana lets you perform advanced data analysis and visualize data in various charts, tables, and maps. You can use it to search, view, and interact with data stored in Elasticsearch indices.

Navigate to <http://kibana.fury.info> or click the Kibana icon from Forecastle.

#### Read the logs

The Fury Logging module already collects data from the following indeces:

- `kubernetes-*`
- `system-*`
- `ingress-controller-*`

Click on `Discover` to see the main dashboard. On the top left cornet select one of the indeces to explore the logs.

![Kibana][kibana-screenshot]

### Grafana

[Grafana](https://github.com/grafana/grafana) is an open-source platform for monitoring and observability. Grafana allows you to query, visualize, alert on and understand your metrics.

Navigate to <http://grafana.fury.info> or click the Grafana icon from Forecastle.

Fury provides some pre-configured dashboard to visualize the state of the cluster. Examine an example dashboard:

1. Click on the search icon on the left sidebar.

2. Write `pods` and click enter.

3. Select the `Kubernetes/Pods` dashboard.

This is what you should see:

![Grafana][grafana-screenshot]

## Step 5 (optional) - Deploy additional modules

We now install other modules:

- dr
- opa

To deploy Velero as Disaster Recovery solution, we need to have credentials to interact with `aws` volumes.

Let's add a module at the bottom of `Furyfile.yml`:

```yaml
versions:
  ...
  dr: v1.7.0
  opa: v1.3.1

bases:
  ...
  - name: dr/velero
  - name: opa/gatekeeper

modules:
- name: dr/gcp-velero
```

And download the new vendor:

```bash
furyctl vendor -H
```

Create the resources using Terraform:

```bash
cd terraform/demo-fury
terraform init
terraform plan -out terraform.plan
terraform apply terraform.plan

# Output the resources to yaml files, so we can use them in kustomize
terraform output -raw velero_backup_storage_location > ../../manifests/demo-fury/resources/velero-backup-storage-location.yml
terraform output -raw velero_volume_snapshot_location > ../../manifests/demo-fury/resources/velero-volume-snapshot-location.yml
terraform output -raw velero_cloud_credentials > ../../manifests/demo-fury/resources/velero-cloud-credentials.yml

```

Let's add the following lines to `kustomization.yaml`:

```yaml
resources:

...

# Disaster Recovery
- ../../vendor/katalog/dr/velero/velero-gcp
- ../../vendor/katalog/dr/velero/velero-schedules
- resources/velero-backup-storage-location.yml
- resources/velero-volume-snapshot-location.yml
- resources/velero-cloud-credentials.yml

# Open Policy Agent
- ../../vendor/katalog/opa/gatekeeper/core
- ../../vendor/katalog/opa/gatekeeper/monitoring
- ../../vendor/katalog/opa/gatekeeper/rules

```

Istall the modules with:

```bash
cd manifest/demo-fury

make apply
# If you see some errors, apply twice
```

## Step 6 - Teardown

To clean up the environment:

```bash
# (Required if you performed Disaster Recovery step)
cd terraform/demo-fury
terraform destroy

# Destroy cluster
cd infrastructure
furyctl cluster destroy

# Destroy network components
cd infrastructure
furyctl bootstrap destroy

#(Optional) Destroy bucket
gsutil -m rm -r gs://fury-gcp-demo/terraform
gsutil rb gs://fury-gcp-demo
```

## Conclusions

I hope you enjoyed the tutorial... TBC

[fury-getting-started-repository]: https://github.com/sighupio/fury-getting-started/
[fury-getting-started-dockerfile]: https://github.com/sighupio/fury-getting-started/blob/main/utils/docker/Dockerfile

[fury-on-minikube]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-minikube
[fury-on-eks]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-eks
[fury-on-gke]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-gke

[furyagent-repository]: https://github.com/sighupio/furyagent

[provisioner-bootstrap-aws-reference]: https://docs.kubernetesfury.com/docs/cli-reference/furyctl/provisioners/aws-bootstrap/

[tunnelblick]: https://tunnelblick.net/downloads.html
[openvpn-connect]: https://openvpn.net/vpn-client/

<!-- Images -->
[kibana-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/kibana.png?raw=true
[grafana-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/grafana.png?raw=true
[cerebro-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/cerebro.png?raw=true
[forecastle-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/forecastle.png?raw=true
