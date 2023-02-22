# Fury on OVHcloud

This step-by-step tutorial guides you to deploy the **Kubernetes Fury Distribution** on a Managed Kubernetes cluster on **OVHcloud**.

This tutorial covers the following steps:

1. Deploy a Managed Kubernetes cluster on OVHcloud with `Terraform`
2. Download the latest version of Fury with `furyctl`
3. Install the Fury distribution
4. Explore some features of the distribution
5. Teardown of the environment

> ⚠️ OVHcloud **charges you** to provision the resources used in this tutorial. You should be charged only a few euros, but we are not responsible for any costs that incur.
>
> ❗️ **Remember to remove all the instances by following all the steps listed in the teardown phase.**
>
> 💻 If you prefer trying Fury in a local environment, check out the [Fury on Minikube][fury-on-minikube] tutorial.

## Prerequisites

This tutorial assumes some basic familiarity with Kubernetes and [OVHcloud](https://www.ovhcloud.com/). Some experience with Terraform is helpful but not required.

To follow this tutorial, you need:

- **OVHcloud Account** - You must have an active account to use OVHcloud services. Use this [guide](https://docs.ovh.com/gb/en/customer/create-ovhcloud-account/) to create one.
- **OVHcloud Public Cloud project** - You must have a Public Cloud Project. Use this [guide](https://docs.ovh.com/gb/en/public-cloud/create_a_public_cloud_project/) to create one.
- **OVHcloud OpenStack User** - To manage the network environment with the Terraform provider, you must have an OpenStack user. Use this [guide](https://docs.ovh.com/gb/en/public-cloud/creation-and-deletion-of-openstack-user/) to create one.

## Step 1 - Automatic provisioning of a Managed Kubernetes Cluster in a private network

We are using the `terraform` CLI to automatically deploy the private network, and then use it for the Managed Kubernetes Cluster.

| Terraform Provider | Credentials |
|---|---|
| [OVH Provider](https://registry.terraform.io/providers/ovh/ovh/latest/docs) | [OVHcloud API](https://docs.ovh.com/gb/en/api/first-steps-with-ovh-api/) credentials |
| [OpenStack Provider](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs) | [OpenStack user](https://docs.ovh.com/sg/en/public-cloud/creation-and-deletion-of-openstack-user/) credentials |

### Pre-requisites

The tools we need are `furyctl`, `terraform`, `kubectl` and `kustomize`.

Click on the desired tool to see how to install it:

<details><summary>1 - furyctl</summary>

Install the latest `furyctl` version from its [Github Furyctl Release page](https://github.com/sighupio/furyctl/releases).

Example on an Ubuntu distribution:

```bash
wget -q "https://github.com/sighupio/furyctl/releases/download/v0.9.0/furyctl-$(uname -s)-amd64" -O /tmp/furyctl \
&& chmod +x /tmp/furyctl \
&& sudo mv /tmp/furyctl /usr/local/bin/furyctl
```

> See [furyctl's readme](https://github.com/sighupio/furyctl) for more installation methods.

</details>

<details><summary>2 - terraform CLI</summary>

Install the latest `terraform` CLI from the [Hashicorp official download page](https://developer.hashicorp.com/terraform/downloads).

Example on an Ubuntu distribution:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform
```

</details>

<details><summary>3 - kubectl</summary>

Install the `kubectl` CLI to manage the Managed Kubernetes Cluster, by following the [Official Kubernetes Documentation](https://kubernetes.io/docs/tasks/tools/).

Example on an Ubuntu distribution:

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
&& sudo mv ./kubectl /usr/local/bin/kubectl \
&& sudo chmod 0755 /usr/local/bin/kubectl
```

</details>

<details><summary>4 - kustomize v3.5.3</summary>

Install the `kustomize` v3.5.3 CLI, by following the [Official Kubernetes Documentation](https://kubectl.docs.kubernetes.io/installation/kustomize/).

Example on an Ubuntu distribution:

```bash
wget https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.5.3/kustomize_v3.5.3_linux_amd64.tar.gz \
&& tar -zxvf ./kustomize_v3.5.3_linux_amd64.tar.gz \
&& chmod u+x ./kustomize \
&& sudo mv ./kustomize /usr/local/bin/kustomize \
&& ./kustomize_v3.5.3_linux_amd64.tar.gz
```

</details>

Or use the `fury-getting-started` docker image:

```bash
docker run -ti --rm \
  -v $PWD:/demo \
  registry.sighup.io/delivery/fury-getting-started
```

Or use the provided `infrastructure/install_dependencies_ubuntu_debian.sh` script to run all the installation commands at once.

### Variables

#### 1 - OVHcloud Terraform Provider variables

To manage OVHcloud components, you must set the same variables as the OVHcloud API ones. Get your API credentials from this [page](https://www.ovh.com/auth/api/createToken).

Give your application a name, a description, and a validity date, then add the rights GET/POST/PUT/DELETE on the endpoint /cloud/project/*.

This returns the 3 values: `Application key`, `Application secret` and `Consumer key`.

Use these values to set up sytem variables like this:

```bash
export OVH_APPLICATION_KEY="xxxxxxxxxxxxxxxxxxxx"
export OVH_APPLICATION_SECRET="xxxxxxxxxxxxxxxxx"
export OVH_CONSUMER_KEY="xxxxxxxxxxxxxxxxxxxxxxx"
```

You also need to define the API endpoint and base URL. Choose the values inside this table according to your localization:

| OVH_ENDPOINT | OVH_BASEURL |
|---|---|
| ovh-eu | https://eu.api.ovh.com/1.0 |
| ovh-us | https://api.us.ovhcloud.com/1.0 |
| ovh-ca | https://ca.api.ovh.com/1.0 |
| kimsufi-eu | https://eu.api.kimsufi.com/1.0 |
| kimsufi-ca | https://ca.api.kimsufi.com/1.0 |
| soyoustart-eu | https://eu.api.soyoustart.com/1.0 |
| soyoustart-ca | https://ca.api.soyoustart.com/1.0 |

Example for `eu` zone:

```bash
export OVH_ENDPOINT=ovh-eu
export OVH_BASEURL="https://eu.api.ovh.com/1.0"
```

The last variable needed by the provider is your Public cloud Id. You can get it from your [OVHcloud Public Cloud dashboard](https://www.ovh.com/manager/#/public-cloud/pci/projects/xxxxxxxxxxxxxxxxxxxxxxx), its the the `xxxxxxxxxxxxxx` part of the URL or copy it from the dashboard just under the project name.

Example:

```bash
export OVH_CLOUD_PROJECT_SERVICE="xxxxxxxxxxxxxxxxxxxxx"
```

That's all you need to use the OVHcloud Terraform Provider.

#### 2 - OVHcloud OpenStack User variables

[Get your OpenStack user's `openrc` file](https://docs.ovh.com/gb/en/public-cloud/set-openstack-environment-variables/#step-1-retrieve-the-variables) to extract and to set necessary variables:

```bash
export OS_AUTH_URL=https://auth.cloud.ovh.net/v3
export OS_IDENTITY_API_VERSION=3
export OS_USER_DOMAIN_NAME=${OS_USER_DOMAIN_NAME:-"Default"}
export OS_PROJECT_DOMAIN_NAME=${OS_PROJECT_DOMAIN_NAME:-"Default"}
export OS_TENANT_ID="xxxxxxxxxxxxxxxxxx"
export OS_TENANT_NAME="xxxxxxxxxxxxxxxx"
export OS_USERNAME="user-xxxxxxxxxxxxxx"
export OS_PASSWORD="xxxxxxxxxxxxxxxxxxx"
export OS_REGION_NAME="xxx"
```

You are ready to use the OpenStack Terraform Provider.

#### 3 - (Optional) Create a variables file from template

You can create an `ovhrc` file from the `ovhrc.template` template, to store your variables.

Example:

```bash
# OpenStack vars from openrc file
export OS_AUTH_URL=https://auth.cloud.ovh.net/v3
export OS_IDENTITY_API_VERSION=3
export OS_USER_DOMAIN_NAME=${OS_USER_DOMAIN_NAME:-"Default"}
export OS_PROJECT_DOMAIN_NAME=${OS_PROJECT_DOMAIN_NAME:-"Default"}
export OS_TENANT_ID="xxxxxxxxxxxxxxxxxx"
export OS_TENANT_NAME="xxxxxxxxxxxxxxxx"
export OS_USERNAME="user-xxxxxxxxxxxxxx"
export OS_PASSWORD="xxxxxxxxxxxxxxxxxxx"
export OS_REGION_NAME="xxx"

# OVH API vars from OVHcloud manager
export OVH_ENDPOINT=ovh-eu
export OVH_BASEURL="https://eu.api.ovh.com/1.0"
export OVH_APPLICATION_KEY="xxxxxxxxxxxxxxx"
export OVH_APPLICATION_SECRET="xxxxxxxxxxxx"
export OVH_CONSUMER_KEY="xxxxxxxxxxxxxxxxxx"
export OVH_CLOUD_PROJECT_SERVICE="xxxxxxxxx" # Must be the same as OS_TENANT_ID
```

Then simply source this file to load all variables into your session:

```bash
source ./ovhrc
```

### Deploy the Kubernetes cluster

We use Terraform to deploy the network and the Managed Kubernetes Cluster. A `variables.tfvars` variable file is present with some default values that you can use as this or change the values if needed:

```terraform
# Region
  
region = "GRA7"

# Network - Private Network

network = {
  name = "furyNetwork"
}

# Network - Subnet

subnet = {
  name       = "furySubnet"
  cidr       = "10.0.0.0/24"
  dhcp_start = "10.0.0.100"
  dhcp_end   = "10.0.0.254"
}

# Network - Router

router = {
  name = "furyRouter"
}

# Managed Kubernetes Cluster

kube = {
  name            = "furykubernetesCluster"
  pv_network_name = "furyNetwork"
  gateway_ip      = "10.0.0.1"
}

pool = {
  name          = "furypool"
  flavor        = "b2-7"
  desired_nodes = "3"
  max_nodes     = "6"
  min_nodes     = "3"
}
```

- `region`: The region where you want to deploy your infrastructure.
- `network`: The network name.
- `subnet`: The subnet parameters, like the CIDR IP format value and DHCP range.
- `router`: The router name.
- `kube`: The Managed Kubernetes Cluster, such as its name and essentially network information.
- `pool`: The Kubernetes node pool parameters.

Deploy the infrastructure with:

```bash
cd infrastructure/terraform

terraform init
terraform plan -var-file=variables.tfvars
terraform apply -var-file=variables.tfvars
```

Wait a few minutes until the end of the deployment.

### Configure your kubectl environment

Once the Managed Kubernetes Cluster has been created, you will get the associated `kubeconfig` file in the `terraform` folder. Set the KUBECONFIG environment variable value like this:

```bash
export KUBECONFIG="$PWD/kubeconfig"
```

Your `kubectl` CLI is ready to use


## Step 2 - Installation

In this section, you use `furyctl` to download the monitoring, logging, and ingress modules of the Fury distribution.

### Inspect the Furyfile

`furyctl` needs a `Furyfile.yml` to know which modules to download.

For this tutorial, use the `Furyfile.yml`:

```yaml
versions:
  monitoring: v2.0.1
  logging: v3.0.1
  ingress: v1.13.1

bases:
  - name: monitoring
  - name: logging
  - name: ingress
```

### Download Fury modules

1. Download the Fury modules with `furyctl`:

```bash
furyctl vendor -H
```

2. Inspect the downloaded modules in the `vendor` folder:

```bash
tree -d vendor -L 3
```

Output:

```bash
$ tree -d vendor -L 3

vendor
└── katalog
    ├── ingress
    │   ├── cert-manager
    │   ├── dual-nginx
    │   ├── external-dns
    │   ├── forecastle
    │   ├── nginx
    │   └── tests
    ├── logging
    │   ├── cerebro
    │   ├── configs
    │   ├── logging-operated
    │   ├── logging-operator
    │   ├── loki-configs
    │   ├── loki-single
    │   ├── opensearch-dashboards
    │   ├── opensearch-single
    │   ├── opensearch-triple
    │   └── tests
    └── monitoring
        ├── aks-sm
        ├── alertmanager-operated
        ├── blackbox-exporter
        ├── configs
        ├── eks-sm
        ├── gke-sm
        ├── grafana
        ├── kubeadm-sm
        ├── kube-proxy-metrics
        ├── kube-state-metrics
        ├── node-exporter
        ├── prometheus-adapter
        ├── prometheus-operated
        ├── prometheus-operator
        ├── tests
        ├── thanos
        └── x509-exporter
```

### Kustomize project

Kustomize allows to group together related Kubernetes resources and combines them to create more complex deployments. 
Moreover, it is flexible, and it enables a simple patching mechanism for additional customization.

To deploy the Fury distribution, use the following root `kustomization.yaml` located `manifests/kustomization.yaml`:

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ingress
  - logging
  - monitoring
```

This `kustomization.yaml` wraps the other `kustomization.yaml`s in subfolders. For example in `manifests/logging/kustomization.yaml`

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../vendor/katalog/logging/cerebro
  - ../../vendor/katalog/logging/logging-operator
  - ../../vendor/katalog/logging/logging-operated
  - ../../vendor/katalog/logging/configs
  - ../../vendor/katalog/logging/opensearch-single
  - ../../vendor/katalog/logging/opensearch-dashboards

  - resources/ingress.yml

patchesStrategicMerge:
  - patches/opensearch-resources.yml
  - patches/cerebro-resources.yml
```

Each `kustomization.yaml`:

- references the modules downloaded in the previous section
- patches the upstream modules (e.g. `patches/opensearch-resources.yml` limits the resources requested by OpenSearch)
- deploys some additional custom resources (e.g. `resources/ingress.yml`)

Install the modules:

```bash
cd manifests/

make apply
# Due to some CRDs being created, the first time you have to run make apply multiple times. Run it until you see no more errors.
make apply
```

## Step 3 - Explore the distribution

🚀 The distribution is finally deployed! In this section, you explore some of its features.

### Setup local DNS

In Step 3, alongside the distribution, you have deployed Kubernetes ingresses to expose underlying services at the following HTTP routes:

- `forecastle.fury.info`
- `grafana.fury.info`
- `opensearch-dashboards.fury.info`

To access the ingresses more easily via the browser, configure your local DNS to resolve the ingresses to the external load balancer IP:

1. Get the address of the external load balancer:

```bash
kubectl get svc -n ingress-nginx ingress-nginx -ojsonpath='{.spec.externalIPs[*]}'
```

2. Add the following line to your machine's `/etc/hosts` (not the container's):

```bash
<EXTERNAL_IP> forecastle.fury.info cerebro.fury.info opensearch-dashboards.fury.info grafana.fury.info
```

Now, you can reach the ingresses directly from your browser.

> ⚠️ We are using an external load-balancer only for the demo purpose. In a real environment, don't expose dashboards on a public network and prefer use internal load balancer.

### Forecastle

[Forecastle](https://github.com/stakater/Forecastle) is an open-source control panel where you can access all exposed applications running on Kubernetes.

Navigate to <http://forecastle.fury.info> to see all the other ingresses deployed, grouped by namespace.

![Forecastle][forecastle-eks-screenshot]

### Grafana

[Grafana](https://github.com/grafana/grafana) is an open-source platform for monitoring and observability. Grafana allows you to query, visualize, alert on and understand your metrics.

Navigate to <http://grafana.fury.info> or click the Grafana icon from Forecastle.

Fury provides some pre-configured dashboards to visualize the state of the cluster. Examine an example dashboard:

1. Click on the search icon on the left sidebar.
2. Write `pods` and click enter.
3. Select the `Kubernetes/Pods` dashboard.

This is what you should see:

![Grafana][grafana-screenshot]

### OpenSearch Dashboards

[OpenSearch Dashboards](https://github.com/opensearch-project/OpenSearch-Dashboards) is an open-source analytics and visualization platform for OpenSearch. OpenSearch Dashboards lets you perform advanced data analysis and visualize data in various charts, tables, and maps. You can use it to search, view, and interact with data stored in OpenSearch indices.

Navigate to <http://opensearch-dashboards.fury.info> or click the OpenSearch Dashboards icon from Forecastle.

> :warning: please beware that some background jobs need to run to finish OpenSearch configuration. If you get a screen with a "Start by adding your data" title, please wait some minutes and try again.

#### Read the logs

The Fury Logging module already collects data from the following indices:

- `kubernetes-*`
- `systemd-*`
- `ingress-controller-*`
- `events-*`

Click on `Discover` to see the main dashboard. On the top left corner select one of the indices to explore the logs.

![Opensearch-Dashboards][opensearch-dashboards-screenshot]

## Step 5 - Teardown

Clean up the demo environment:

```bash
cd ../infrastructure/terraform/
terraform destroy -var-file=variables.tfvars
```

## Conclusions

Congratulations, you made it! 🥳🥳

We hope you enjoyed this tour of Fury on OVHcloud!

### Issues/Feedback

In case your ran into any problems feel free to open an issue here on GitHub.

### Where to go next?

More tutorials:

- [Fury on GKE][fury-on-gke]
- [Fury on EKS][fury-on-eks]
- [Fury on Minikube][fury-on-minikube]

More about Fury:

- [Fury Documentation][fury-docs]

<!-- Links -->
[fury-getting-started-repository]: https://github.com/sighupio/fury-getting-started/
[fury-getting-started-dockerfile]: https://github.com/sighupio/fury-getting-started/blob/main/utils/docker/Dockerfile

[fury-on-minikube]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-minikube
[fury-on-gke]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-gke
[fury-on-eks]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-eks

[furyagent-repository]: https://github.com/sighupio/furyagent

[fury-docs]: https://docs.kubernetesfury.com
[opa-module-docs]: https://docs.kubernetesfury.com/docs/modules/opa/overview

<!-- Images -->
<!-- `media` here is a branch. We used to store all images in that branch and reference them from other branches -->
[grafana-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/grafana.png?raw=true
[opensearch-dashboards-screenshot]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch_dashboards.png?raw=true
[forecastle-eks-screenshot]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/forecastle_eks.png?raw=true
