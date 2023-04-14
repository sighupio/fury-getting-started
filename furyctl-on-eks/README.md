# Furyctl on EKS

This step-by-step tutorial guides you to deploy the **Kubernetes Fury Distribution** (KFD) on an EKS cluster on AWS.

This tutorial covers the following steps:

1. Configure the EKS cluster with the configuration file `furyctl.yaml`
2. Deploy an EKS Kubernetes cluster on AWS with `furyctl`
3. Explore the Fury Kubernetes Distribution
4. Teardown of the environment

> ⚠️ AWS **charges you** to provision the resources used in this tutorial. You should be charged only a few dollars, but we are not responsible for any costs that incur.
>
> ❗️ **Remember to stop all the instances by following all the steps listed in the [teardown phase](#step-4---teardown).**

## Prerequisites

This tutorial assumes some basic familiarity with Kubernetes and AWS. Some experience with Terraform is helpful but not required.

To follow this tutorial, you need:

- **AWS Access Credentials** of an AWS Account with the following [IAM permissions][terraform-aws-eks-iam-permissions].
- **Docker** - the tutorial uses a [Docker image][fury-getting-started-dockerfile] containing `furyctl` and all the necessary tools to follow it.
- **OpenVPN Client** - [Tunnelblick][tunnelblick] (on macOS) or [OpenVPN Connect][openvpn-connect] (for other OSes) are recommended, [OpenVPN client][openvpn-client] is required
when using the flag `--vpn-auto-connect` in the `furyctl create/delete cluster` command.
- **AWS S3 Bucket** to store the Terraform state.
- **GitHub** account with [SSH key configured][github-ssh-key-setup].
- **AWS CLI** - version 2.8.12 at the time of writing this tutorial. You can check your version by running `aws --version`. If you don't have it installed, follow the [official guide][aws-cli-installation].

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
export AWS_PROFILE=<YOUR_AWS_PROFILE_NAME>
```

If you don't have an AWS profile configured, you can create one by running the following command:

```bash
$ aws configure --profile <YOUR_AWS_PROFILE_NAME>
AWS Access Key ID [None]: <YOUR_AWS_ACCESS_KEY_ID>
AWS Secret Access Key [None]: <YOUR_AWS_SECRET_ACCESS_KEY>
Default region name [None]: <YOUR_AWS_REGION>
Default output format [None]: json
```

You are all set ✌️.

## Step 1 - Configure the EKS cluster via `furyctl.yaml` 

`furyctl` is a command-line tool developed by SIGHUP to support:

- the automatic provisioning of Kubernetes clusters in a number of cloud environments
- the installation of the Fury distribution

The configuration of the Fury cluster is governed by the `furyctl.yaml` file, which for the purposes of this tutorial 
is located in `/demo/furyctl.yaml`
This file contains the information needed to set up the cluster and the
configuration and consists of the following sections:

- **infrastructure**: contains the information related to the infrastructure (VPC and VPN) provisioning phase.
- **kubernetes**: contains the information related to the provisioning phase of the Kubernetes cluster.
- **distribution**: contains information related to the provisioning phase of the distribution.

There is also an initial part that defines settings common to all sections.

### Initial section

The initial section of the `furyctl.yaml` file contains the following parameters:

```yaml
apiVersion: kfd.sighup.io/v1alpha2
kind: EKSCluster
metadata:
  name: <CLUSTER_NAME>
spec:
  distributionVersion: "v1.25.1"
  toolsConfiguration:
    terraform:
      state:
        s3:
          bucketName: <S3_TFSTATE_BUCKET>
          keyPrefix: <S3_TFSTATE_BUCKET_KEY_PREFIX>
          region: <S3_TFSTATE_BUCKET_REGION>
  region: <CLUSTER_REGION>
  tags:
    env: "test"
```

Open the `/demo/furyctl.yaml` file with a text editor of your choice and replace the field `<CLUSTER_NAME>` with a name of your choice for the cluster, and the field `<CLUSTER_REGION>` with the AWS region where you want to deploy the cluster. 
If you already have a S3 bucket to store the Terraform state, replace the field `<S3_TFSTATE_BUCKET>`, `<S3_TFSTATE_BUCKET_KEY_PREFIX>`, `<S3_TFSTATE_BUCKET_REGION>`
with the data from the bucket, otherwise you can create a new one by following the following steps:

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

> ℹ️ You might need to give permissions on S3 to the user.

### Infrastructure section

The infrastructure section of the `furyctl.yaml` file contains the following parameters:

```yaml
  infrastructure:
    vpc:
      network:
        cidr: 10.0.0.0/16
        subnetsCidrs:
          private:
            - 10.0.182.0/24
            - 10.0.172.0/24
            - 10.0.162.0/24
          public:
            - 10.0.20.0/24
            - 10.0.30.0/24
            - 10.0.40.0/24
    vpn:
      vpnClientsSubnetCidr: 192.168.200.0/24
      ssh:
        publicKeys:
          - <SSH_PUBLIC_KEY>
        githubUsersName:
          - <GITHUB_USER>
        allowedFromCidrs:
          - 0.0.0.0/0
```

Replace the field `<GITHUB_USER>` with your actual GitHub username, and the field `<SSH_PUBLIC_KEY>` with the public key you want to use to access the bastion host.
You can choose different subnet CIDRs should you prefer.

From this, `furyctl` will automatically provision:

- **Virtual Private Cloud (VPC)** in a specified CIDR range with public and private subnets
- **EC2 instance** bastion host with an OpenVPN Server
- All the required networking gateways and routes

More details about the infrastructure provisioner can be found [here][provisioner-infrastructure-aws-reference].

### Kubernetes section

The Kubernetes section of the `furyctl.yaml` file contains the following parameters:

```yaml
  kubernetes:
    nodePoolsLaunchKind: "launch_templates"
    nodeAllowedSshPublicKey: <SSH_PUBLIC_KEY>
    apiServer:
      privateAccess: true
      publicAccess: false
      privateAccessCidrs: ['0.0.0.0/0']
    nodePools:
      - name: infra
        size:
          min: 3
          max: 3
        instance:
          type: t3.xlarge
        labels:
          nodepool: infra
          node.kubernetes.io/role: infra
        taints:
          - node.kubernetes.io/role=infra:NoSchedule
        tags:
          k8s.io/cluster-autoscaler/node-template/label/nodepool: "infra"
          k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/role: "infra"
          k8s.io/cluster-autoscaler/node-template/taint/node.kubernetes.io/role: "infra:NoSchedule"
```

Replace the field `<SSH_PUBLIC_KEY>` with the public key you want to use to access the worker nodes.
You can add different nodePools, or edit the existing one should you prefer.

From this `furyctl` automatically deploys a battle-tested private EKS Cluster.

More details about the kubernetes provisioner can be found [here][provisioner-kubernetes-aws-reference].

### Distribution section

The Distribution section of the `furyctl.yaml` file contains the following parameters:

```yaml
  distribution:
    modules:
      ingress:
        baseDomain: internal.demo.example.dev
        nginx:
          type: dual
          tls:
            provider: certManager
        certManager:
          clusterIssuer:
            name: letsencrypt-fury
            email: admin@example.dev
            type: dns01
        dns:
          public:
            name: demo.example.dev
            create: true
          private:
            create: true
            name: internal.demo.example.dev
      logging:
        opensearch:
          type: single
          resources:
            limits:
              cpu: 2000m
              memory: 4G
            requests:
              cpu: 300m
              memory: 1G
      dr:
        velero:
          eks:
            region: eu-west-1
            bucketName: <S3_VELERO_BUCKET_NAME>
```

Replace the field `<S3_VELERO_BUCKET_NAME>` with the name of the S3 bucket that will be used to store the Velero backups.
You can configure the existing modules or add new ones (take a look to the [docs][fury-distribution-eks-reference]) should you prefer.

From this `furyctl` automatically deploys a battle-tested Fury Kubernetes Distribution.

## Step 2 - Provisioning an EKS Cluster Automatically with Furyctl

In this section, you will utilize Furyctl to automatically provision an EKS Cluster, making the deployment process streamlined.

1. Start by running the Furyctl command to create the cluster:

```bash
furyctl create cluster
```   

2. Upon being prompted to connect to the VPN, simply open the .ovpn file via your OpenVPN Client application.

3. Connect to the OpenVPN Server via the chosen OpenVPN Client and continue by pressing `enter`

4. Once connected to the VPN the process will continue to provision the cluster and the distribution.

> ⏱ The process will take several minutes to complete, you can follow the progress in detail by running the following command:
>
> ```bash
> tail -f /root/.furyctl/furyctl.log
> ```

🚀 Success! The distribution is fully deployed. Proceed to the next section to explore the various features it has to offer.

## Step 3 - Explore the Fury Kubernetes Distribution

### Setup local DNS

In the previous section, alongside the distribution, you have deployed Kubernetes ingresses to expose underlying services at the following HTTP routes:

- `directory.internal.demo.example.dev`
- `gpm.internal.demo.example.dev`
- `cerebro.internal.demo.example.dev`
- `grafana.internal.demo.example.dev`
- `opensearch-dashboards.internal.demo.example.dev`

To access the ingresses more easily via the browser, configure your local DNS to resolve the ingresses to the internal load balancer IP:

1. Get the IP address of the internal load balancer:

```bash
dig $(kubectl get svc ingress-nginx-internal -n ingress-nginx --no-headers | awk '{print $4}')
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
<FIRST_IP> directory.internal.demo.example.dev cerebro.internal.demo.example.dev opensearch-dashboards.internal.demo.example.dev grafana.internal.demo.example.dev gpm.internal.demo.example.dev
```

Now, you can reach the ingresses directly from your browser.

### Forecastle

[Forecastle](https://github.com/stakater/Forecastle) is an open-source control panel where you can access all exposed applications running on Kubernetes.

Navigate to <http://directory.internal.demo.example.dev> to see all the other ingresses deployed, grouped by namespace.

![Forecastle][forecastle-eks-screenshot]

### OpenSearch Dashboards

[OpenSearch Dashboards](https://github.com/opensearch-project/OpenSearch-Dashboards) is an open-source analytics and visualization platform for OpenSearch. OpenSearch Dashboards lets you perform advanced data analysis and visualize data in various charts, tables, and maps. You can use it to search, view, and interact with data stored in OpenSearch indices.

Navigate to <http://opensearch-dashboards.internal.demo.example.dev> or click the OpenSearch Dashboards icon from Forecastle.

#### Manually Create OpenSearch Dashboards Indexes (optional)

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

Navigate to <http://grafana.internal.demo.example.dev> or click the Grafana icon from Forecastle.

Fury provides some pre-configured dashboards to visualize the state of the cluster. Examine an example dashboard:

1. Click on the search icon on the left sidebar.
2. Write `pods` and click enter.
3. Select the `Kubernetes/Pods` dashboard.

This is what you should see:

![Grafana][grafana-screenshot]

## Step 4 (optional) - Advanced Distribution usage

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

> 💡 **TIP** Gatekeeper Policy Manger, a simple readonly web UI to easily see the deployed policies and their status is installed as part of the OPA module. You can access it at <http://gpm.internal.demo.example.dev/>

## Step 5 - Teardown

Clean up the demo environment:

1. Delete the EKS cluster and all the related aws resources:

```bash
furyctl delete cluster
```

2. Write 'yes' and hit enter, when prompted to confirm the deletion.

3. (Optional) Destroy the S3 bucket holding the Terraform state

```bash
aws s3api delete-objects --bucket $S3_BUCKET \
  --delete "$(aws s3api list-object-versions --bucket $S3_BUCKET --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"

aws s3api delete-bucket --bucket $S3_BUCKET
```

4. Exit from the docker container:

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

[provisioner-infrastructure-aws-reference]: https://github.com/sighupio/fury-eks-installer/tree/master/modules/vpc-and-vpn
[provisioner-kubernetes-aws-reference]: https://github.com/sighupio/fury-eks-installer/tree/master/modules/eks

[tunnelblick]: https://tunnelblick.net/downloads.html
[openvpn-connect]: https://openvpn.net/vpn-client/
[openvpn-client]: https://openvpn.net/community-downloads/ 
[github-ssh-key-setup]: https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account

[fury-docs]: https://docs.kubernetesfury.com
[opa-module-docs]: https://docs.kubernetesfury.com/docs/modules/opa/overview

[aws-cli-installation]: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-version.html

[fury-distribution-eks-reference]: https://github.com/sighupio/fury-distribution/blob/feature/ng-add-support-for-public-eks-clusters/templates/config/ekscluster-kfd-v1alpha2.yaml.tpl

<!-- Images -->
<!-- `media` here is a branch. We used to store all images in that branch and reference them from other branches -->
[grafana-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/grafana.png?raw=true
[opensearch-dashboards-screenshot]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch_dashboards.png?raw=true
[opensearch-dashboards-welcome]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch_dashboards_welcome.png?raw=true
[opensearch-dashboards-discover]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch_dashboards_discover.png?raw=true
[opensearch-dashboards-index]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch_dashboards_index.png?raw=true
[forecastle-eks-screenshot]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/forecastle_eks.png?raw=true
