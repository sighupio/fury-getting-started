# Fury on EKS

This step-by-step tutorial guides you to deploy the **Kubernetes Fury Distribution** on an EKS cluster on AWS.

This tutorial covers the following steps:

1. Deploy an EKS Kubernetes cluster on AWS with `furyctl`.
2. Download the latest version of Fury with `furyctl`.
3. Install the Fury distribution.
4. Explore some features of the distribution.
5. (optional) Deploy additional modules of the distribution.
6. Teardown of the environment.

> ⚠️ AWS **will charge you** to provision the resources used in this tutorial. You should be charged only a few dollars, but we are not responsible for any charges that may incur.

> ❗️ **Remember to stop all the instances by following all the steps listed in the teardown phase.**

> 💻 If you prefer trying Fury in a local environment, check out the [Fury on Minikube][fury-on-minikube] tutorial.

## Prerequisites

This tutorial assumes some basic familiarity with Kubernetes and AWS. Some experience with Terraform is helpful but not strictly required.

To follow this tutorial, you need:

- **AWS Access Credentials** of an AWS Account with the following [IAM permissions](https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/iam-permissions.md).
- **Docker** - a [Docker image]([fury-on-eks-dockerfile]) containing `furyctl` and all the necessary tools is provided.
- **OpenVPN Client** - [Tunnelblick][tunnelblick] (on macOS) or [OpenVPN Connect][openvpn-connect] (for other OS) are recommended.
- **AWS S3 Bucket** (optional) to hold the Terraform state.

### Setup and initialize the environment

1. Open a terminal

2. Run the `fury-eks` docker image:

```bash
docker run -ti -v $PWD:/demo docker run -ti -v $PWD:/demo registry.sighup.io/delivery/fury-eks
```

3. Clone the [fury getting started repository][fury-getting-started-repository] containing all the example code used in this tutorial:

```bash
git clone <REPO_LINK>
```

4. Setup your AWS credentials by exporting the following environment variables:

```bash
export AWS_ACCESS_KEY_ID=<YOUR_AWS_ACCESS_KEY_ID>
export AWS_SECRET_ACCESS_KEY=<YOUR_AWS_SECRET_ACCESS_KEY>
export AWS_DEFAULT_REGION=<YOUR_AWS_REGION>
```

In alternative, you can authenticate with AWS by running `aws configure` in your terminal. When prompted, enter your AWS Access Key ID, Secret Access Key, region and output format.

```bash
$ aws configure
AWS Access Key ID [None]: <YOUR_AWS_ACCESS_KEY_ID>
AWS Secret Access Key [None]: <YOUR_AWS_SECRET_ACCESS_KEY>
Default region name [None]: <YOUR_AWS_REGION>
Default output format [None]: json
```

You are all set ✌️.

## Step 1 - Automatic provisioning of an EKS Cluster

You will use `furyctl` to automatically provision an EKS cluster. `furyctl` is a command-line tool developed by SIGHUP to support:

- the automatic provisioning of Kubernetes clusters in various environments.
- the installation of the Fury distribution.

The provisioning process is divided into two phases:

1. **Bootstrap** provisioning phase
2. **Cluster** provisioning phase

### Boostrap provisioning phase

In the bootstrap phase, `furyctl` automatically provisions:

- **Virtual Private Cloud (VPC)** in a specified CIDR range with public and private subnets.
- **EC2 instance** bastion host with an OpenVPN Server.
- All the required networking gateways and routes.

More details about the bootstrap provisioner can be found [here][provisioner-bootstrap-aws-reference].

#### Configuration

The bootstrap provisioner takes a `bootstrap.yml` as input. This file instructs the bootstrap provisioner with all the needed parameters to deploy the networking infrastructure.

In the repository, you can find a template for this file at `infrastructure/bootstrap/bootstrap.yml`:

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
  version: 0.13.6
  # state:
  #   backend: s3
  #   config:
  #     bucket: <S3_BUCKET>
  #     key: <S3_BUCKET_KEY>
  #     region: <S3_BUCKET_REGION>
provisioner: aws
```

Open the `bootstrap.yml` file with a text editor of your choice and:

- Replace the field `<GITHUB_USER>` with your actual GitHub username.
- Make sure that the VPC and subnets ranges are not already in use. If so, specify different values in the fields:
  - `networkCIDR`
  - `publicSubnetsCIDRs`
  - `privateSubnetsCIDRs`
- (optional) Add the details of an **existing** AWS Bucket to hold the Terraform remote state.


> ⚠️ The bootstrap provisioner does not create the S3 bucket for you. You can manually create it using the AWS CLI:

```bash
aws s3api create-bucket --bucket <S3_BUCKET> --region <S3_BUCKET_REGION> --create-bucket-configuration LocationConstraint=<S3_BUCKET_REGION>
```

Leave the rest as configured. More details about each field can be found [here][provisioner-bootstrap-aws-reference].

#### Provision networking infrastructure

1. Initialize the bootstrap provisioner:

```bash
cd infrastructure/bootstrap
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


> 📝 This phase may take some minutes. You can inspect the logs at: `infrastructure/bootstrap/bootstrap/logs/terraform.logs`.

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

In the cluster provisioning phase, `furyctl`  automatically deploys a battle-tested private EKS Cluster. To interact with the private EKS cluster, you first need to connect to private network via the bastion host.

#### Connect to private network

1. Create the `fury.ovpn` OpenVPN credentials file with `furyagent`:

```bash
furyagent configure openvpn-client \ 
  --client-name fury \
  --config /demo/infrastructure/bootstrap/bootstrap/secrets/furyagent.yml \
  > fury.ovpn
```


> 🕵🏻‍♂️ [Furyagent][furyagent-repository] is a tool developed by SIGHUP to manage OpenVPN and SSH user access to the bastion host.

2. Check that the `fury` user is now listed:

```bash
furyagent configure openvpn-client --list \
--config /demo/infrastructure/bootstrap/bootstrap/secrets/furyagent.yml
```

Output:

```
2021-06-07 14:37:52.169664 I | storage.go:146: Item pki/vpn-client/fury.crt found [size: 1094]
2021-06-07 14:37:52.169850 I | storage.go:147: Saving item pki/vpn-client/fury.crt ...
2021-06-07 14:37:52.265797 I | storage.go:146: Item pki/vpn/ca.crl found [size: 560]
2021-06-07 14:37:52.265879 I | storage.go:147: Saving item pki/vpn/ca.crl ...
+------+------------+------------+---------+--------------------------------+
| USER | VALID FROM |  VALID TO  | EXPIRED |            REVOKED             |
+------+------------+------------+---------+--------------------------------+
| fury | 2021-06-07 | 2022-06-07 | false   | false 0001-01-01 00:00:00      |
|      |            |            |         | +0000 UTC                      |
+------+------------+------------+---------+--------------------------------+
```

3. Open the `fury.ovpn` file with any OpenVPN Client.

4. Connect to the OpenVPN Server via the OpenVPN Client.

#### Provision Cluster

The cluster provisioner takes a `cluster.yml` as input. This file instructs the provisioner with all the needed parameters to deploy the EKS cluster.

In the repository, you can find a template for this file at `infrastructure/bootstrap/cluster.yml`:

```yaml
kind: Cluster
metadata:
  name: fury-eks-demo
spec:
  version: 1.18
  network: <VPC_ID>
  subnetworks:
  - <PRIVATE_SUBNET1_ID>
  - <PRIVATE_SUBNET2_ID>
  - <PRIVATE_SUBNET3_ID>
  dmzCIDRRange:
  - 10.0.0.0/16
  sshPublicKey: example-ssh-key
  nodePools:
  - name: fury
    version: null
    minSize: 3
    maxSize: 3 
    instanceType: t3.large
    volumeSize: 50
executor:
  version: 0.13.6
  # state:
  #   backend: s3
  #   config:
  #     bucket: <S3_BUCKET>
  #     key: <MY_KEY> 
  #     region: <S3_BUCKET_REGION>
provisioner: eks
```

Open the file with a text editor and replace:

- `<VPC_ID>` with the VPC ID of the previous phase (`vpc-0d2fd9bcb4f68379e`) created in the previous phase.
- `<PRIVATE_SUBNET1_ID>` with ID of the first private subnet ID (`subnet-072b1e3405f662c70`) created in the previous phase.
- `<PRIVATE_SUBNET2_ID>` with ID of the second private subnet ID (`subnet-subnet-0a23db3b19e5a7ed7`) created in the previous phase.
- `<PRIVATE_SUBNET3_ID>` with ID of the third private subnet ID (`subnet-08f4930148ab5223f`) created in the previous phase.
- (optional) Add the details of an **existing** AWS Bucket to hold the Terraform remote state. If you are using the same bucket as before, please specify a different **key**.

Initialize the cluster provisioner and create the cluster:

```bash
cd ../infrastructure/cluster

# Initialize cluster provisioner
furyctl cluster init

# Create cluster
furyctl cluster apply
```


> 📝 This phase may take some minutes. You can inspect the logs at: `infrastructure/bootstrap/bootstrap/logs/terraform.logs`.

When the `furyctl cluster apply` is complete, inspect the output and find the command to retrieve the `KUBECONFIG`.

```bash
export KUBECONFIG=<PATH_TO_KUBECONFIG>
```

Test the connection with the cluster:

```bash
kubectl get nodes
```

## Step 2 - Download fury modules

`furyctl` can do a lot more than deploying infrastructure. In this section, you will use `furyctl` to download the monitoring, logging, and ingress modules of the Fury distribution.

The Fury distribution has various modules that you can install. Each module provides specific functionality to your cluster. In this section, we download 

To download the modules, A `Furyfile.yml` tells `furyctl` which modules to download.

In this tutorial, you use the following `Furyfile.yml`:

```yaml
versions:
  monitoring: v1.12
  logging: v1.8
  ingress: v1.10

resources:
  - name: monitoring/prometheus-operator
  - name: monitoring/prometheus-operated
  - name: monitoring/alertmanager-operated
  - name: monitoring/grafana
  - name: monitoring/goldpinger
  - name: monitoring/configs
  - name: monitoring/eks-sm
  - name: monitoring/kube-proxy-metrics
  - name: monitoring/kube-state-metrics
  - name: monitoring/node-exporter
  - name: monitoring/metrics-server
  - name: logging/elasticsearch-single
  - name: logging/cerebro
  - name: logging/curator
  - name: logging/fluentd
  - name: logging/kibana
  - name: ingress/nginx
  - name: ingress/cert-manager
  - name: ingress/forecastle
```

Download the modules with `furyctl`:

```bash
furyctl vendor -H
```

Inspect the download modules in the `vendor` folder:

```bash
$ tree -d vendor -L 2

vendor
└── katalog
    ├── ingress
    ├── logging
    └── monitoring
```

## Step 3 - Installation

Each module is a Kustomize project. Kustomize allows to group together related Kubernetes resources and combine them to create more complex deployment. Moreover, it is flexible, and it enables a simple patching mechanism for additional customization.

To deploy the Fury distribution, use the main `manifests/demo-fury/kustomization.yaml` file:

```yaml
resources:

# Ingress module
- ../../vendor/katalog/ingress/forecastle
- ../../vendor/katalog/ingress/nginx
- ../../vendor/katalog/ingress/cert-manager

# Logging module
- ../../vendor/katalog/logging/cerebro
- ../../vendor/katalog/logging/curator
- ../../vendor/katalog/logging/elasticsearch-single
- ../../vendor/katalog/logging/fluentd
- ../../vendor/katalog/logging/kibana

# Monitoring module
- ../../vendor/katalog/monitoring/alertmanager-operated
- ../../vendor/katalog/monitoring/goldpinger
- ../../vendor/katalog/monitoring/grafana
- ../../vendor/katalog/monitoring/kube-proxy-metrics
- ../../vendor/katalog/monitoring/kube-state-metrics
- ../../vendor/katalog/monitoring/eks-sm
- ../../vendor/katalog/monitoring/metrics-server
- ../../vendor/katalog/monitoring/node-exporter
- ../../vendor/katalog/monitoring/prometheus-operated
- ../../vendor/katalog/monitoring/prometheus-operator

# Custom resources
- resources/ingress.yml

patchesStrategicMerge:

# Ingress module
- patches/ingress-nginx-lb-annotation.yml

# Logging module
- patches/fluentd-resources.yml
- patches/fluentbit-resources.yml

# Monitoring module
- patches/alertmanager-resources.yml
- patches/cerebro-resources.yml
- patches/elasticsearch-resources.yml
- patches/prometheus-operator-resources.yml
- patches/prometheus-resources.yml
```

This `kustomization.yaml`:

- references the modules downloaded in the previous sections
- patches the upstream modules (e.g. `patches/elasticsearch-resources.yml` limits the resources requested by elastic search)
- deploys some additional custom resources (e.g. `resources/ingress.yml`)

Install the modules:

```bash
cd manifest/demo-fury

make apply
# You will see some errors related to CRDs creation, apply twice
make apply
```

## Step 4 - Explore the distribution

In this section, we explore some features of the distribution.

### Setup local DNS

1. Get the address of the internal loadbalancer:

```bash
# Get the Load Balancer endpoint
kubectl get svc ingress-nginx -n ingress-nginx
```

Output:

```bash
NAME                    TYPE           CLUSTER-IP       EXTERNAL-IP                       PORT(S)                      AGE
ingress-nginx           LoadBalancer   <SOME_IP>        xxx.elb.eu-west-1.amazonaws.com   80:31080/TCP,443:31443/TCP   103m
```

The address is listed under `EXTERNAL-IP` column, `xxx.elb.eu-west-1.amazonaws.com` in our case.

2. Resolve the address to get the Load Balancer IP

```bash
dig xxx.elb.eu-west-1.amazonaws.com
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

3. Add the following line to your local `/etc/hosts`:

```bash
<FIRST_IP> forecastle.fury.info cerebro.fury.info kibana.fury.info grafana.fury.info
```

Now, you can reach the ingresses directly from your browser.

### Forecastle

[Forecastle](https://github.com/stakater/Forecastle) is an open-source control panel where you can access all exposed applications running on Kubernetes.

Navigate to <http://forecastle.fury.info> to see all the other ingresses deployed, grouped by namespace.

![Forecastle](../../static/img/fury-demo-eks-forecastle.png)

### Kibana

[Kibana](https://github.com/elastic/kibana) is an open-source analytics and visualization platform for Elasticsearch. Kibana lets you perform advanced data analysis and visualize data in various charts, tables, and maps. You can use it to search, view, and interact with data
stored in Elasticsearch indices.

Navigate to <http://kibana.fury.info> or click the Kibana icon from Forecastle.

Click on `Explore on my own` and you should see the dashboard.

#### Create a Kibana index

Open the menu on the right-top corner of the page, and select `Stack Management` (it's on the very bottom of the menu). Then select `Index patterns` and click on `Create index pattern`.

Write `kubernetes-*` as index pattern and flag *Include system and hidden indices*, then click `Next step`.

Select `@timestamp` as time field and create the index.

#### Read the logs

Based on our index, now we can read and query the logs. Let's navigate through the menu again, and select `Discover`.

![Kibana](../../static/img/fury-demo-eks-kibana.png)

### Grafana

[Grafana](https://github.com/grafana/grafana) is an open-source platform for monitoring and observability. It allows you to query, visualize, alert on and understand your metrics.

Navigate to <http://grafana.fury.info> or click the Grafana icon from Forecastle.

Fury provides some dashboard already configured to use.

Let's examine an example dashboard. Write `pods` and select the `Kubernetes/Pods` dashboard. This is what you should see:

![Grafana](../../static/img/fury-demo-eks-grafana.png)

## Step 5 (optional) - Deploy additional modules

We now install other modules:

- dr
- opa

To deploy Velero as Disaster Recovery solution, we need to have credentials to interact with `aws` volumes.

Let's add a module at the bottom of `Furyfile.yml`:

```yaml
versions:
  ...
  dr: v1.6.1
  opa: v1.3.1

bases:
  ...
  - name: dr/velero
  - name: opa/gatekeeper

modules:
- name: dr/eks-velero
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
terraform output -raw velero_patch > ../../manifests/demo-fury/patches/velero.yml
terraform output -raw velero_backup_storage_location > ../../manifests/demo-fury/resources/velero-backup-storage-location.yml
terraform output -raw velero_volume_snapshot_location > ../../manifests/demo-fury/resources/velero-volume-snapshot-location.yml
```

Let's add the following lines to `kustomization.yaml`:

```yaml
resources:

...

# Disaster Recovery
- ../../vendor/katalog/dr/velero/velero-aws
- ../../vendor/katalog/dr/velero/velero-schedules
- resources/velero-backup-storage-location.yml
- resources/velero-volume-snapshot-location.yml

# Open Policy Agent
- ../../vendor/katalog/opa/gatekeeper/core
- ../../vendor/katalog/opa/gatekeeper/monitoring
- ../../vendor/katalog/opa/gatekeeper/rules

patchesStrategicMerge:
...

# Disaster Recovery
- patches/velero.yml
...
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
cd infrastructure/cluster
furyctl cluster destroy

# Find and delete the target groups associated with the Fury demo cluster 
# cluster using AWS CLI (make sure to use the tag corresponding to your cluster)
target_groups=$(aws resourcegroupstaggingapi get-resources \
                --tag-filters Key=kubernetes.io/cluster/fury-eks-demo,Values=owned  \
                | jq -r ".ResourceTagMappingList[] | .ResourceARN" | grep targetgroup)
for tg in $target_groups ; do aws elbv2 delete-target-group --target-group-arn $tg ; done

# Similarly delete the loadbalancer associated with the cluster as well
loadbalancer=$(aws resourcegroupstaggingapi get-resources  \
               --tag-filters Key=kubernetes.io/cluster/fury-eks-demo,Values=owned \
               | jq -r ".ResourceTagMappingList[] | .ResourceARN" | grep loadbalancer)
for i in $loadbalancer ; do aws elbv2 delete-load-balancer -load-balancer-arn $i ; done

# Destroy network components
cd infrastructure/bootstrap
furyctl bootstrap destroy

#(Optional) Destroy bucket
aws s3api delete-object --bucket <S3_BUCKET> --key furyctl/bootstrap
aws s3api delete-object --bucket <S3_BUCKET> --key furyctl/cluster
aws s3api delete-bucket --bucket <S3_BUCKET>
```

## Conclusions

I hope you enjoyed the tutorial... TBC

[fury-getting-started-repository]: https://github.com/sighupio/fury-getting-started/
[fury-getting-started-dockerfile]: https://github.com/sighupio/fury-getting-started/blob/main/utils/docker/Dockerfile

[fury-on-minikube]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-minikube
[fury-on-eks]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-eks
[fury-on-gke]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-gke

[fury-modules]: 🔥🔥🔥

[furyagent-repository]: https://github.com/sighupio/furyagent

[provisioner-bootstrap-aws-reference]: https://docs.kubernetesfury.com/docs/cli-reference/furyctl/provisioners/aws-bootstrap/

[tunnelblick]: https://tunnelblick.net/downloads.html
[openvpn-connect]: https://openvpn.net/vpn-client/
