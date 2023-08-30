# Fury on EKS

This step-by-step tutorial guides you to deploy the **Kubernetes Fury Distribution** (KFD) on an EKS cluster on AWS.

This tutorial covers the following steps:

1. Deploy an EKS Kubernetes cluster on AWS with `furyctl`
2. Download the latest version of KFD with `furyctl`
3. Install the Kubernetes Fury Distribution
4. Explore some features of the distribution
5. (optional) Deploy additional modules of the Fury distribution
6. Teardown of the environment

> ⚠️ AWS **charges you** to provision the resources used in this tutorial. You should be charged only a few dollars, but we are not responsible for any costs that incur.
>
> ❗️ **Remember to stop all the instances by following all the steps listed in the [teardown phase](#step-6---teardown).**
>
> 💻 If you prefer trying Fury in a local environment, check out the [Fury on Minikube][fury-on-minikube] tutorial.

## Prerequisites

This tutorial assumes some basic familiarity with Kubernetes and AWS. Some experience with Terraform is helpful but not required.

To follow this tutorial, you need:

- **AWS Access Credentials** of an AWS Account with the following [IAM permissions][terraform-aws-eks-iam-permissions].
- **Docker** - the tutorial uses a [Docker image][fury-getting-started-dockerfile] containing `furyctl` and all the necessary tools to follow it.
- **OpenVPN Client** - [Tunnelblick][tunnelblick] (on macOS) or [OpenVPN Connect][openvpn-connect] (for other OS) are recommended.
- **AWS S3 Bucket** (optional) to store the Terraform state.
- **GitHub** account with [SSH key configured][github-ssh-key-setup].

### Setup and initialize the environment

1. Open a terminal

2. Clone the [fury getting started repository][fury-getting-started-repository] containing the example code used in this tutorial:

```bash
git clone https://github.com/sighupio/fury-getting-started/
cd fury-getting-started/fury-on-eks
```

3. Run the `fury-getting-started` docker image:

```bash
docker run -ti --rm \
  -v $PWD:/demo \
  registry.sighup.io/delivery/fury-getting-started
```

4. Setup your AWS credentials by exporting the following environment variables:

```bash
export AWS_ACCESS_KEY_ID=<YOUR_AWS_ACCESS_KEY_ID>
export AWS_SECRET_ACCESS_KEY=<YOUR_AWS_SECRET_ACCESS_KEY>
export AWS_DEFAULT_REGION=<YOUR_AWS_REGION>
```

Alternatively, authenticate with AWS by running `aws configure` in your terminal. When prompted, enter your AWS Access Key ID, Secret Access Key, region, and output format. Notice that this won't set the environment variable `AWS_DEFAULT_REGION` that is required later. Please set it manually.

```bash
$ aws configure
AWS Access Key ID [None]: <YOUR_AWS_ACCESS_KEY_ID>
AWS Secret Access Key [None]: <YOUR_AWS_SECRET_ACCESS_KEY>
Default region name [None]: <YOUR_AWS_REGION>
Default output format [None]: json
```

You are all set ✌️.

## Step 1 - Automatic provisioning of an EKS Cluster with furyctl

`furyctl` is a command-line tool developed by SIGHUP to support:

- the automatic provisioning of Kubernetes clusters in various cloud environments
- the installation of the Fury distribution

The provisioning process is divided into two phases:

1. **Bootstrap** provisioning phase
2. **Cluster** provisioning phase

### Boostrap provisioning phase

In the bootstrap phase, `furyctl` automatically provisions:

- **Virtual Private Cloud (VPC)** in a specified CIDR range with public and private subnets
- **EC2 instance** bastion host with an OpenVPN Server
- All the required networking gateways and routes

More details about the bootstrap provisioner can be found [here][provisioner-bootstrap-aws-reference].

#### Configure the bootstrap provisioner

The bootstrap provisioner takes a `bootstrap.yml` as input. This file, instructs the bootstrap provisioner with all the needed parameters to deploy the networking infrastructure.

For this tutorial, use the `bootstrap.yml` template located at `/demo/infrastructure/bootstrap.yml`:

```yaml
kind: Bootstrap
metadata:
  name: fury-eks-demo
spec:
  networkCIDR: 10.0.0.0/16
  publicSubnetsCIDRs:
  - 10.0.1.0/24
  - 10.0.2.0/24
  - 10.0.3.0/24
  privateSubnetsCIDRs:
  - 10.0.101.0/24
  - 10.0.102.0/24
  - 10.0.103.0/24
  vpn:
    instances: 1
    port: 1194
    instanceType: t3.micro
    diskSize: 50
    operatorName: fury
    dhParamsBits: 2048
    subnetCIDR: 172.16.0.0/16
    sshUsers:
    - <GITHUB_USER>
executor:
  # state:
  #   backend: s3
  #   config:
  #     bucket: <S3_BUCKET>
  #     key: furyctl/boostrap
  #     region: <S3_BUCKET_REGION>
provisioner: aws
```

Open the `/demo/infrastructure/bootstrap.yml` file with a text editor of your choice and replace the field `<GITHUB_USER>` with your actual GitHub username. You can choose different subnet CIDRs should you prefer.

Leave the rest as configured. More details about each field can be found [here][provisioner-bootstrap-aws-reference].

#### (optional) Create an S3 Bucket to hold the Terraform remote

Although this is a tutorial, it is always a good practice to use a remote Terraform state over a local one. In case you are not familiar with Terraform, you can skip this section.

1. Choose a unique name and an AWS region for the S3 Bucket:

```bash
export S3_BUCKET=fury-demo-eks              # Use a different name
export S3_BUCKET_REGION=$AWS_DEFAULT_REGION # You can use the same region than before.
```

2. Create the S3 bucket using the AWS CLI:

```bash
aws s3api create-bucket \
  --bucket $S3_BUCKET \
  --region $S3_BUCKET_REGION \
  --create-bucket-configuration LocationConstraint=$S3_BUCKET_REGION
```

> ℹ️  You might need to give permissions on S3 to the user.

3. Once created, uncomment the `spec.executor.state` block in the `/demo/infrastructure/bootstrap.yml` file:

```yaml
...
executor:
  state:
   backend: s3
   config:
     bucket: <S3_BUCKET>
     key: fury/boostrap
     region: <S3_BUCKET_REGION>
```

4. Replace the `<S3_BUCKET>` and `<S3_BUCKET_REGION>` placeholders with the correct values from the previous commands:

```yaml
...
executor:
  state:
   backend: s3
   config:
     bucket: fury-demo-eks # example value
     key: fury/boostrap
     region: eu-central-1  # example value
```

#### Provision networking infrastructure

1. Initialize the bootstrap provisioner:

```bash
cd /demo/infrastructure/
furyctl bootstrap init
```

In case you run into errors, you can re-initialize the bootstrap provisioner by adding the  `--reset` flag:

```bash
furyctl bootstrap init --reset
```

2. If the initialization succeeds, apply the bootstrap provisioner:

```bash
furyctl bootstrap apply
```

> ⏱ This phase may take some minutes.
>
> Logs are available at `/demo/infrastructure/bootstrap/logs/terraform.logs`.

3. When the `furyctl bootstrap apply` completes, inspect the output:

```bash
...
All the bootstrap components are up to date.

VPC and VPN ready:

VPC: vpc-0d2fd9bcb4f68379e
Public Subnets: [subnet-0bc905beb6622f446, subnet-0c6856acb42edf8f3, subnet-0272dcf88b2f5d12c]
Private Subnets: [subnet-072b1e3405f662c70, subnet-0a23db3b19e5a7ed7, subnet-08f4930148ab5223f]

Your VPN instance IPs are: [34.243.133.186]
...
```

In particular, take note of:

- **VPC** - `vpc-0d2fd9bcb4f68379e` in the example output above
- **Private Subnets** - `[subnet-072b1e3405f662c70, subnet-0a23db3b19e5a7ed7, subnet-08f4930148ab5223f]` in the example output above

These values are used in the cluster provisioning phase.

### Cluster provisioning phase

In the cluster provisioning phase, `furyctl` automatically deploys a battle-tested private EKS Cluster. To interact with the private EKS cluster, connect first to the private network via the OpenVPN server in the bastion host.

#### Connect to the private network

1. Create the `fury.ovpn` OpenVPN credentials file with `furyagent`:

```bash
furyagent configure openvpn-client \
  --client-name fury \
  --config /demo/infrastructure/bootstrap/secrets/furyagent.yml > fury.ovpn
```

> 🕵🏻‍♂️ [Furyagent][furyagent-repository] is a tool developed by SIGHUP to manage OpenVPN and SSH user access to the bastion host.

2. Check that the `fury` user is now listed:

```bash
furyagent configure openvpn-client \
  --list \
  --config /demo/infrastructure/bootstrap/secrets/furyagent.yml
```

Output:

```bash
2022-12-09 15:29:02.853807 I | storage.go:146: Item pki/vpn-client/fury.crt found [size: 1094]
2022-12-09 15:29:02.853961 I | storage.go:147: Saving item pki/vpn-client/fury.crt ...
2022-12-09 15:29:02.975943 I | storage.go:146: Item pki/vpn/ca.crl found [size: 560]
2022-12-09 15:29:02.975991 I | storage.go:147: Saving item pki/vpn/ca.crl ...
+------+------------+------------+---------+--------------------------------+
| USER | VALID FROM |  VALID TO  | EXPIRED |            REVOKED             |
+------+------------+------------+---------+--------------------------------+
| fury | 2022-12-09 | 2023-12-09 | false   | false 0001-01-01 00:00:00      |
|      |            |            |         | +0000 UTC                      |
+------+------------+------------+---------+--------------------------------+
```

3. Open the `fury.ovpn` file with any OpenVPN Client.

4. Connect to the OpenVPN Server via the chosen OpenVPN Client.

#### Configure the cluster provisioner

The cluster provisioner takes a `cluster.yml` as input. This file instructs the provisioner with all the needed parameters to deploy the EKS cluster.

In the repository, you can find a template for this file at `/demo/infrastructure/cluster.yml`:

```yaml
kind: Cluster
metadata:
  name: fury-eks-demo
spec:
  version: 1.25
  network: <VPC_ID>
  subnetworks:
  - <PRIVATE_SUBNET1_ID>
  - <PRIVATE_SUBNET2_ID>
  - <PRIVATE_SUBNET3_ID>
  dmzCIDRRange:
  - 10.0.0.0/16
  sshPublicKey: example-ssh-key # ⚠️ put your id_rsa.pub file content here
  nodePoolsLaunchKind: "launch_templates"
  nodePools:
  - name: fury
    version: null
    minSize: 3
    maxSize: 3 
    instanceType: t3.large
    volumeSize: 50
executor:
  # state:
  #   backend: s3
  #   config:
  #     bucket: <S3_BUCKET>
  #     key: furyctl/cluster
  #     region: <S3_BUCKET_REGION>
provisioner: eks
```

Open the file with a text editor and replace:

- `<VPC_ID>` with the VPC ID (`vpc-0d2fd9bcb4f68379e`) created in the previous phase.
- `<PRIVATE_SUBNET1_ID>` with ID of the first private subnet ID (`subnet-072b1e3405f662c70`) created in the previous phase.
- `<PRIVATE_SUBNET2_ID>` with ID of the second private subnet ID (`subnet-subnet-0a23db3b19e5a7ed7`) created in the previous phase.
- `<PRIVATE_SUBNET3_ID>` with ID of the third private subnet ID (`subnet-08f4930148ab5223f`) created in the previous phase.
- `sshPublicKey` with the contents of your public SSH key (usually located at `~/.ssh/id_rsa.pub`).
- (optional) As before, add the details of the S3 Bucket that holds the Terraform remote state.

> ⚠️ if you are using an S3 bucket to store the Terraform state make sure to use a **different key** in `executor.state.config.key` field than the one used in the boorstrap phase.

#### Provision EKS Cluster

1. Initialize the cluster provisioner:

```bash
furyctl cluster init
```

2. Create EKS cluster:

> ⏱ The following command takes several minutes to complete.
>
> Logs are available at `/demo/infrastructure/cluster/logs/terraform.logs`.

```bash
furyctl cluster apply
```

3. When the `furyctl cluster apply` completes, test the connection with the cluster:

```bash
export KUBECONFIG=/demo/infrastructure/cluster/secrets/kubeconfig
kubectl get nodes
```

> 💡 **TIP**: the `kubectl` command has been aliased to `k` inside the container.

## Step 2 - Download KFD modules

`furyctl` can do a lot more than deploy infrastructure. In this section, you use `furyctl` to download the monitoring, logging, and ingress modules of KFD.

### Inspect the Furyfile

`furyctl` needs a `Furyfile.yml` to know which modules to download.

For this tutorial, use the `Furyfile.yml` located at `/demo/Furyfile.yaml`:

```yaml
versions:
  networking: v1.12.2
  monitoring: v2.1.0
  logging: v3.1.3
  ingress: v1.14.1
  dr: v1.11.0
  auth: v0.0.3
  aws: v2.2.0
  opa: v1.8.0

bases:
  - name: networking
  - name: monitoring
  - name: logging
  - name: ingress
  - name: aws
  - name: dr
  - name: opa

modules:
  - name: aws
  - name: dr
```

> 💡 **TIP**: you can also download the `Furyfile.yml` and a sample `kustomization.yaml` for a specific version of the Kubernetes Fury Distribution with the folllowing command:
>
> ```console
> furyctl init --version v1.25.0
> ```

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
├── katalog
│  ├── aws
│  │  ├── cluster-autoscaler
│  │  ├── ebs-csi-driver
│  │  ├── load-balancer-controller
│  │  └── node-termination-handler
│  ├── dr
│  │  ├── tests
│  │  └── velero
│  ├── ingress
│  │  ├── cert-manager
│  │  ├── dual-nginx
│  │  ├── external-dns
│  │  ├── forecastle
│  │  ├── nginx
│  │  └── tests
│  ├── logging
│  │  ├── cerebro
│  │  ├── configs
│  │  ├── logging-operated
│  │  ├── logging-operator
│  │  ├── loki-configs
│  │  ├── loki-single
│  │  ├── opensearch-dashboards
│  │  ├── opensearch-single
│  │  ├── opensearch-triple
│  │  └── tests
│  ├── monitoring
│  │  ├── aks-sm
│  │  ├── alertmanager-operated
│  │  ├── blackbox-exporter
│  │  ├── configs
│  │  ├── eks-sm
│  │  ├── gke-sm
│  │  ├── grafana
│  │  ├── kube-proxy-metrics
│  │  ├── kube-state-metrics
│  │  ├── kubeadm-sm
│  │  ├── node-exporter
│  │  ├── prometheus-adapter
│  │  ├── prometheus-operated
│  │  ├── prometheus-operator
│  │  ├── tests
│  │  ├── thanos
│  │  └── x509-exporter
│  ├── networking
│  │  ├── calico
│  │  ├── ip-masq
│  │  ├── tests
│  │  └── tigera
│  └── opa
│     ├── gatekeeper
│     └── tests
└── modules
   ├── aws
   │  ├── iam-for-cluster-autoscaler
   │  ├── iam-for-ebs-csi-driver
   │  └── iam-for-load-balancer-controller
   └── dr
      ├── aws-velero
      ├── azure-velero
      └── gcp-velero
```

## Step 3 - Installation

### Terraform project

Each module can contain Kustomize bases or Terraform modules.

First of all, you need to initialize the additional Terraform project to create resources needed by Velero in the DR module and EBS CSI Driver in the AWS module.

Inside the repository, you can find a Terraform file at `/demo/terraform/main.tf`. Edit this file and change the values for the S3 bucket that will store the Terraform state for the new resources:

```terraform
terraform {
#   backend "s3" {
#     bucket = <S3_BUCKET>
#     key    = fury/distribution
#     region = <S3_BUCKET_REGION>
#   }
  required_version = ">= 0.15.4"

  required_providers {
    aws        = "=3.37.0"
  }
}

```

Then, create a file `terraform.tfvars` in the `/demo/terraform` folder with the following content (change the values accordingly to your environment):

```terraform
cluster_name = "fury-eks-demo"
velero_bucket_name = "velero-demo-sa"
```

Then apply the terraform project:

```bash
cd /demo/terraform/

make init
make plan
make apply
```

After everything is applied, extract the kustomize patches we need in the next step with the following command:

```bash
make generate-output
```

### Kustomize project

Kustomize allows grouping related Kubernetes resources and combining them to create more complex deployments.
Moreover, it is flexible, and it enables a simple patching mechanism for additional customization.

To deploy the Fury distribution, use the following root `kustomization.yaml` located at `/demo/manifests/kustomization.yaml`:

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ingress
  - logging
  - monitoring
  - networking
  - dr
  - opa
  - aws
```

This `kustomization.yaml` wraps other `kustomization.yaml` files present in each module subfolder. For example in `/demo/manifests/logging/kustomization.yaml` you'll find:

```yaml
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

Each `kustomization.yaml` file:

- references the modules downloaded in the previous section
- patches the upstream modules that we downloaded with a custom configuration for this environment (e.g. `patches/opensearch-resources.yml` limits the resources requested by OpenSearch)
- deploys some additional custom resources not included in the modules (e.g. `resources/ingress.yml`)

Install the modules:

```bash
cd /demo/manifests/

make apply
# Wait a momento for the Kubernetes API server to process the new CRDs and for the nginx-ingress-contorllers to become READY, and then run again the apply command.
make apply
```

## Step 4 - Explore the distribution

🚀 The distribution is finally deployed! In this section, you explore some of its features.

### Setup local DNS

In Step 3, alongside the distribution, you have deployed Kubernetes ingresses to expose underlying services at the following HTTP routes:

- `forecastle.fury.info`
- `gpm.fury.info`
- `grafana.fury.info`
- `opensearch-dashboards.fury.info`

To access the ingresses more easily via the browser, configure your local DNS to resolve the ingresses to the internal load balancer IP:

1. Get the IP address of the internal load balancer:

```bash
dig $(kubectl get svc ingress-nginx -n ingress-nginx --no-headers | awk '{print $4}')
```

Output:

```bash
...

;; ANSWER SECTION:
xxx.elb.eu-west-1.amazonaws.com. 77 IN A <FIRST_IP>
xxx.elb.eu-west-1.amazonaws.com. 77 IN A <SECOND_IP>
xxx.elb.eu-west-1.amazonaws.com. 77 IN A <THIRD_IP>
...

```

3. Add the following line to your machine's `/etc/hosts` (not the container's):

```bash
<FIRST_IP> forecastle.fury.info cerebro.fury.info opensearch-dashboards.fury.info grafana.fury.info gpm.fury.info
```

Now, you can reach the ingresses directly from your browser.

### Forecastle

[Forecastle](https://github.com/stakater/Forecastle) is an open-source control panel where you can access all exposed applications running on Kubernetes.

Navigate to <http://forecastle.fury.info> to see all the other ingresses deployed, grouped by namespace.

![Forecastle][forecastle-eks-screenshot]

### OpenSearch Dashboards

[OpenSearch Dashboards](https://github.com/opensearch-project/OpenSearch-Dashboards) is an open-source analytics and visualization platform for OpenSearch. OpenSearch Dashboards lets you perform advanced data analysis and visualize data in various charts, tables, and maps. You can use it to search, view, and interact with data stored in OpenSearch indices.

Navigate to <http://opensearch-dashboards.fury.info> or click the OpenSearch Dashboards icon from Forecastle.

#### Manually Create OpenSearch Dashboards Indeces (optional)

If when you access OpenSearch Dashboards you get welcomed with the following message:

![opensearch-dashboards-welcome][opensearch-dashboards-welcome]

this means that the Indexes have not been created yet. This is expected the first time you deploy the logging stack. We deploy a set of cron jobs that take care of creating them but they may not have run yet (they run every hour).

You can trigger them manually with the following commands:

```bash
kubectl create job -n logging --from cronjob/index-patterns-cronjob manual-indexes
kubectl create job -n logging --from cronjob/ism-policy-cronjob manual-ism-policy
```

Wait a moment for the jobs to finish and try refreshing the OpenSearch Dashboard page.

#### Discover the logs

To work with the logs arriving into the system, click on "OpenSearch Dashboards" icon on the main page, and then on the "Discover" option or navigate through the side ("hamburger") menu and select `Discover` (see image below).

![opensearch-dashboards-discover][opensearch-dashboards-discover]

![Opensearch-Dashboards][opensearch-dashboards-screenshot]

Follow the next steps to query the logs collected by the logging stack:

![opensearch-dashboards-index][opensearch-dashboards-index]

You can choose between different index options:

- `audit-*` Kubernetes API server audit logs.
- `events-*`: Kubernetes events.
- `infra-*`: logs for infrastructural components deployed as part of KFD
- `ingress-controller-*`: logs from the NGINX Ingress Controllers running in the cluster.
- `kubernetes-*`: logs for applications running in the cluster that are not part of KFD. *Notice that this index will most likely be empty until you deploy an application*.
- `systemd-*` logs collected from a selection of systemd services running in the nodes like containerd and kubelet.

Once you selected your desired index, then you can search them by writing queries in the search box. You can also filter the results by some criteria, like pod name, namespaces, etc.

### Grafana

[Grafana](https://github.com/grafana/grafana) is an open-source platform for monitoring and observability. Grafana allows you to query, visualize, alert, and understand your metrics.

Navigate to <http://grafana.fury.info> or click the Grafana icon from Forecastle.

Fury provides some pre-configured dashboards to visualize the state of the cluster. Examine an example dashboard:

1. Click on the search icon on the left sidebar.
2. Write `pods` and click enter.
3. Select the `Kubernetes/Pods` dashboard.

This is what you should see:

![Grafana][grafana-screenshot]

## Step 5 (optional) - Advanced Distribution usage

### (optional) Create a backup with Velero

1. Create a backup with the `velero` command-line utility:

```bash
velero backup create --from-schedule manifests test -n kube-system
```

2. Check the backup status:

```bash
velero backup get -n kube-system
```

### (optional) Enforce a Policy with OPA Gatekeeper

OPA Gatekeeper has been deployed as part of the distribution, [the module comes with a set of policies pre-defined][opa-module-docs].

To test drive the default rules, try to create a simple deployment in the `default` namespace:

```bash
kubectl run --image busybox bad-pod -n default
```

You should get an error from Gatekeeper saying that the pod is not compliant with the current policies.

Gatekeeper runs as a Validating Admission Webhook, meaning that all the requests to the Kubernetes API server are validated first by Gatekeeper before saving them to the cluster's state.

If you list the pods in the `default` namespace, the list it should be empty, confirming that the pod creation was actually rejected:

```console
$ kubectl get pods -n default
No resources found in default namespace.
```

Some namespaces are exempted from the default policies, for exmaple `kube-system`. Try to create the same pod in the `kube-system` namespace and it should succeed.

```bash
kubectl run --image busybox bad-pod -n kube-system
```

Output should be:

```console
pod/bad-pod created
```

> 💡 **TIP** Gatekeeper Policy Manger, a simple readonly web UI to easily see the deployed policies and their status is installed as part of the OPA module. You can access it at <http://gpm.fury.info/>

## Step 6 - Teardown

Clean up the demo environment:

1. Delete the namespaces containing external resources like volumes and load balancers:

```bash
kubectl delete namespace logging monitoring ingress-nginx
```

> If the command takes too long to finish you can cancel it with <kbd>⌃ Control</kbd> + <kbd>C</kbd>

Wait until the namespaces are completely deleted, or that:

```bash
kubectl get pvc -A
# and 
kubectl get svc -A
```

return no result for `pvc` and no LoadBalancer for `svc`.

2. Destroy the additional Terraform resources used by Velero:

```bash
cd /demo/terraform/
terraform destroy
```

3. Destroy EKS cluster:

```bash
cd /demo/infrastructure/
furyctl cluster destroy
```

4. Some resources are created outside Terraform, for example when you create a LoadBalancer service it will create an ELB in AWS. You can find a script to delete the target groups, load balancers, volumes, and snapshots associated with the EKS cluster using AWS CLI:

> ✋🏻 Edit the script and check that the `TAG_KEY` variable has the right value before running the script. It should end with the cluster name.

```bash
bash cleanup.sh
```

5. Destroy network infrastructure (remember to disconnect from the VPN before deleting):

```bash
furyctl bootstrap destroy
```

5. (Optional) Destroy the S3 bucket holding the Terraform state

```bash
aws s3api delete-objects --bucket $S3_BUCKET \
  --delete "$(aws s3api list-object-versions --bucket $S3_BUCKET --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"

aws s3api delete-bucket --bucket $S3_BUCKET
```

6. Exit from the docker container:

```bash
exit
```

## Conclusions

Congratulations, you made it! 🥳🥳

We hope you enjoyed this tour of Fury!

### Issues/Feedback

In case you ran into any problems feel free to [open an issue in GitHub](https://github.com/sighupio/fury-getting-started/issues/new).

### Where to go next?

More tutorials:

- [Fury on GKE][fury-on-gke]
- [Fury on OVHcloud][fury-on-ovhcloud]
- [Fury on Minikube][fury-on-minikube]

More about Fury:

- [Fury Documentation][fury-docs]

<!-- Links -->
[terraform-aws-eks-iam-permissions]: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/v17.24.0/docs/iam-permissions.md
[fury-getting-started-repository]: https://github.com/sighupio/fury-getting-started/
[fury-getting-started-dockerfile]: https://github.com/sighupio/fury-getting-started/blob/main/utils/docker/Dockerfile

[fury-on-minikube]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-minikube
[fury-on-gke]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-gke
[fury-on-ovhcloud]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-ovhcloud

[furyagent-repository]: https://github.com/sighupio/furyagent

[provisioner-bootstrap-aws-reference]: https://github.com/sighupio/fury-eks-installer/tree/master/modules/vpc-and-vpn

[tunnelblick]: https://tunnelblick.net/downloads.html
[openvpn-connect]: https://openvpn.net/vpn-client/
[github-ssh-key-setup]: https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account

[fury-docs]: https://docs.kubernetesfury.com
[opa-module-docs]: https://docs.kubernetesfury.com/docs/modules/opa/overview

<!-- Images -->
<!-- `media` here is a branch. We used to store all images in that branch and reference them from other branches -->
[grafana-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/grafana.png?raw=true
[opensearch-dashboards-screenshot]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch_dashboards.png?raw=true
[opensearch-dashboards-welcome]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch-dashboards_welcome.png?raw=true
[opensearch-dashboards-discover]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch-dashboards_discover.png?raw=true
[opensearch-dashboards-index]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch-dashboards_index.png?raw=true
[forecastle-eks-screenshot]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/forecastle_eks.png?raw=true
