# Fury on minikube

This step-by-step tutorial helps you deploy a subset of the **Kubernetes Fury Distribution** on a local minikube cluster.

This tutorial covers the following steps:

1. Deploy a local minikube cluster.
2. Download the latest version of Fury with `furyctl`.
3. Install Fury distribution.
4. Explore some features of the distribution.
5. Teardown the environment.

> ☁️ If you prefer trying Fury in a cloud environment, check out the [Fury on EKS](../fury-on-eks) tutorial or the [Fury on GKE](../fury-on-gke) tutorial.

The goal of this tutorial is to introduce you to the main concepts of KFD and how to work with its tooling.

## Prerequisites

This tutorial assumes some basic familiarity with Kubernetes.

To follow this tutorial, you need:

- **minikube** - follow the [installation guide](https://minikube.sigs.k8s.io/docs/start/). This guide is based on minikube with the VirtualBox driver.
- **Docker** - we provide you with a [Docker image][fury-getting-started-dockerfile] containing `furyctl` and all the necessary tools.

### Setup and initialize the environment

1. Open a terminal

2. Clone the [fury getting started repository](https://github.com/sighupio/fury-getting-started) containing all the example code used in this tutorial:

```bash
git clone https://github.com/sighupio/fury-getting-started/
cd fury-getting-started/fury-on-minikube
```

## Step 1 - Start the minikube cluster

1. Start minikube cluster:

```bash
export REPO_DIR=$PWD 
export KUBECONFIG=$REPO_DIR/infrastructure/kubeconfig
cd $REPO_DIR/infrastructure
make setup
```

> ⚠️ This command will spin up by default a single-node Kubernetes v1.25.8 cluster, using VirtualBox driver, with 4 CPUs, 8GB RAM and 20 GB Disk. Take a look at the [Makefile](infrastructure/Makefile) to change the default values.
>
> You can also pass custom parameters, for example:
>
> ```bash
> make setup cpu=4 memory=4096 driver=hyperkit
> ```

2. Run the `fury-getting-started` container:

```bash
docker run -ti --rm \
  -v $REPO_DIR:/demo \
  --env KUBECONFIG=/demo/infrastructure/kubeconfig \
  --net=host \
  registry.sighup.io/delivery/fury-getting-started
```

3. Test the connection to the minikube cluster:

```console
kubectl get nodes
```

Output:

```console
NAME       STATUS   ROLES           AGE    VERSION
minikube   Ready    control-plane   104s   v1.25.8
```

> 💡 **TIP**: the `kubectl` command has been aliased to `k` inside the container.

## Step 2 - Download Fury modules

`furyctl` can do a lot more than deploy infrastructure. In this section, you use `furyctl` to download the monitoring, logging, and ingress modules of the Fury distribution.

To learn more about `furyctl` and its features, head to the [documentation site][furyctl-docs].

### Inspect the Furyfile

`furyctl` needs a `Furyfile.yml` to know which modules to download.

For this tutorial, use the `Furyfile.yml` located at `/demo/Furyfile.yaml`, here is its content:

```yaml
versions:
  monitoring: v2.1.0
  logging: v3.1.3
  ingress: v1.14.1

bases:
  - name: monitoring/prometheus-operator
  - name: monitoring/prometheus-operated
  - name: monitoring/prometheus-adapter
  - name: monitoring/alertmanager-operated
  - name: monitoring/grafana
  - name: monitoring/kubeadm-sm
  - name: monitoring/configs
  - name: monitoring/kube-state-metrics
  - name: monitoring/kube-proxy-metrics
  - name: monitoring/node-exporter
  
  - name: logging/opensearch-single
  - name: logging/opensearch-dashboards
  - name: logging/logging-operator
  - name: logging/logging-operated
  - name: logging/configs
  - name: logging/minio-ha

  - name: ingress/cert-manager
  - name: ingress/forecastle
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
tree -d /demo/vendor -L 2
```

Output:

```bash
/demo/vendor
└── katalog
    ├── ingress
    ├── logging
    └── monitoring
```

## Step 3 - Installation

Each module is a [Kustomize](https://kustomize.io/) project. Kustomize allows grouping related Kubernetes resources and combining them to create more complex deployments. Moreover, it is flexible, and it enables a simple patching mechanism for additional customization.

To deploy the Fury distribution, use the following root `kustomization.yaml` located `/demo/manifests/kustomization.yaml`:

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:

  # Monitoring
  - ../vendor/katalog/monitoring/prometheus-operator
  - ../vendor/katalog/monitoring/prometheus-operated
  - ../vendor/katalog/monitoring/prometheus-adapter
  - ../vendor/katalog/monitoring/grafana
  - ../vendor/katalog/monitoring/kube-state-metrics
  - ../vendor/katalog/monitoring/kube-proxy-metrics
  - ../vendor/katalog/monitoring/kubeadm-sm
  - ../vendor/katalog/monitoring/node-exporter
  - ../vendor/katalog/monitoring/alertmanager-operated

  # Logging
  - ../vendor/katalog/logging/opensearch-single
  - ../vendor/katalog/logging/opensearch-dashboards
  - ../vendor/katalog/logging/logging-operator
  - ../vendor/katalog/logging/logging-operated
  - ../vendor/katalog/logging/configs
  - ../vendor/katalog/logging/minio-ha

  # Ingress
  - ../vendor/katalog/ingress/forecastle

  # Ingress definitions
  - resources/ingress.yml

# With this patches, we customize the default configuration of the modules, 
# for example lowering the resource requirements to make it run in minikube.
patchesStrategicMerge:
  - patches/alertmanager-operated-replicas.yml
  - patches/alertmanager-operated-resources.yml
  - patches/prometheus-operated-resources.yml
  - patches/grafana-resources.yml
  - patches/opensearch-resources.yml
  - patches/logging-operated-resources.yml
```

This `kustomization.yaml`:

- references the modules downloaded in the previous section
- patches the modules that we downloaded with a custom configuration for this environment (e.g. `patches/opensearch-resources.yml` limits the resources requested by OpenSearch)
- deploys some additional custom resources not included in the modules (e.g. `resources/ingress.yml`)

Install the modules:

```bash
cd /demo/manifests/

make apply
# Wait a moment to let the Kubernetes API server process the new APIs defined by the CRDs and for the NGINX Ingress Controller pod to be ready and apply again
make apply
```

Wait for all the pods to become ready:

```console
watch kubectl get pods -A
```

Press <kbd>⌃ Control</kbd> + <kbd>C</kbd> to exit the watch command once all the pods are in `Running` state.

## Step 4 - Explore the distribution

🚀 The (subset of the) distribution is finally deployed! In this section you will explore some of its features.

### Setup local DNS

In Step 3, alongside the distribution, you have deployed Kubernetes ingresses to expose underlying services at the following HTTP routes:

- `directory.fury.info`
- `grafana.fury.info`
- `logs.fury.info`

To access the ingresses more easily via the browser, configure your local DNS to resolve the ingresses to the external minikube IP:

> ℹ️ the following commands should be executed in another terminal of your host. Not inside the fury-getting-started container.

1. Get the address of the cluster IP:

```bash
minikube ip
<SOME_IP>
```

3. Add the following line to your local `/etc/hosts`:

```bash
<SOME_IP> directory.fury.info alertmanager.fury.info grafana.fury.info prometheus.fury.info logs.fury.info

```

Now, you can reach the ingresses directly from your browser.

### Forecastle

[Forecastle](https://github.com/stakater/Forecastle) is an open-source control panel where you can access all exposed applications running on Kubernetes.

Navigate to <http://directory.fury.info> to see all the other ingresses deployed, grouped by namespace.

![Forecastle][forecastle-screenshot]

### OpenSearch Dashboards

[OpenSearch](https://github.com/opensearch-project) is an open-source analytics and visualization platform. OpenSearch Dashboards lets you perform advanced data analysis and visualize data in various charts, tables, and maps. You can use it to search, view, and interact with data stored in Elasticsearch indices.

Navigate to <http://logs.fury.info> or click the OpenSearch Dashboards icon in Forecastle.

#### Manually Create OpenSearch Dashboards Indeces (optional)

If when you access OpenSearch Dashboards you get welcomed with the following message:

![opensearch-dashboards-welcome][opensearch-dashboards-welcome]

this means that the Indexes have not been created yet. This is expected the first time you deploy the logging stack. We deploy a set of cron jobs that take care of creating them but they may not have run yet (they run every hour).

You can trigger them manually with the following commands:

```bash
kubectl create job -n logging --from cronjob/index-patterns-cronjob manual-indexes
kubectl create job -n logging --from cronjob/ism-policy-cronjob manual-ism-policy
```

Wait a moment for the jobs to finish and try refreshing OpenSearch Dashboard page.

#### Discover the logs

To work with the logs arriving into the system, click on "OpenSearch Dashboards" icon on the main page, and then on the "Discover" option or navigate through the side ("hamburger") menu and select `Discover` (see image below).

![opensearch-dashboards-discover][opensearch-dashboards-discover]

![opensearch-dashboards][opensearch-dashboards-screenshot]

Follow the next steps to query the logs collected by the logging stack:

![opensearch-dashboards-index][opensearch-dashboards-index]

You can choose between different index options:

- `audit-*` Kubernetes API server audit logs.
- `events-*`: Kubernetes events.
- `infra-*`: logs for infrastructural components deployed as part of KFD
- `ingress-controller-*`: logs from the NGINX Ingress Controllers running in the cluster.
- `kubernetes-*`: logs for applications running in the cluster that are not part of KFD. *Notice that this index will most likely be empty until you deploy an application*.
- `systemd-*` logs collected form a selection of systemd services running in the nodes like containerd and kubelet.

Once you selected your desired index, then you can search them by writing queries in the search box. You can also filter the results by some criteria, like pod name, namespaces, etc.


### Grafana

[Grafana](https://github.com/grafana/grafana) is an open-source platform for monitoring and observability. Grafana allows you to query, visualize, alert, and understand your metrics.

Navigate to <http://grafana.fury.info> or click the Grafana icon from Forecastle.

Fury provides pre-configured dashboards to visualize the state of the cluster and all its components. Examine an example dashboard:

1. Click on the search icon on the left sidebar.
2. Write `pods` and press enter.
3. Select the `Kubernetes/Pods` dashboard.

This is what you should see:

![Grafana][grafana-screenshot]

Make sure to select a namespace that has pods running and then select one of those pods.

Take a look around and test the other dashboards available.

## Step 6 - Tear down

1. Stop the docker container:

```bash
# ⚠️ Execute this command inside the Docker container
exit
```

2. Delete the minikube cluster:

```bash
# ⚠️ Execute these commands from your local system, outside the Docker container
cd $REPO_DIR/infrastructure
make delete
```

## Conclusions

Congratulations, you made it! 🥳🥳

We hope you enjoyed this tour of Fury!

### Issues/Feedback

In case you ran into any problems feel free to [open an issue in GitHub](https://github.com/sighupio/fury-getting-started/issues/new).

### Where to go next?

More tutorials:

- [Fury on EKS][fury-on-eks]
- [Fury on GKE][fury-on-gke]
- [Fury on OVHcloud][fury-on-ovhcloud]

More about Fury:

- [Fury Documentation][fury-docs]

<!-- Links -->
[fury-getting-started-repository]: https://github.com/sighupio/fury-getting-started/
[fury-getting-started-dockerfile]: https://github.com/sighupio/fury-getting-started/blob/main/utils/docker/Dockerfile

[fury-on-minikube]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-minikube
[fury-on-eks]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-eks
[fury-on-gke]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-gke
[fury-on-ovhcloud]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-ovhcloud

[furyagent-repository]: https://github.com/sighupio/furyagent

[provisioner-bootstrap-aws-reference]: https://docs.kubernetesfury.com/docs/cli-reference/furyctl/provisioners/aws-bootstrap/

[tunnelblick]: https://tunnelblick.net/downloads.html
[openvpn-connect]: https://openvpn.net/vpn-client/
[github-ssh-key-setup]: https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account

[fury-docs]: https://docs.kubernetesfury.com
[fury-docs-modules]: https://docs.kubernetesfury.com/docs/overview/modules/

[furyctl-docs]: https://docs.kubernetesfury.com/docs/infrastructure/furyctl

<!-- Images -->
[opensearch-dashboards-screenshot]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch_dashboards.png?raw=true
[opensearch-dashboards-welcome]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch_dashboards_welcome.png?raw=true
[opensearch-dashboards-discover]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch_dashboards_discover.png?raw=true
[opensearch-dashboards-index]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/opensearch_dashboards_index.png?raw=true
[grafana-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/grafana.png?raw=true
[forecastle-screenshot]: https://github.com/sighupio/fury-getting-started/blob/main/utils/images/forecastle.png?raw=true
