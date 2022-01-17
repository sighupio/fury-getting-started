# Fury on Minikube

This step-by-step tutorial helps you deploy the **Kubernetes Fury Distribution** on a local minikube cluster.

This tutorial covers the following steps:

1. Deploy a local Minikube cluster.
2. Download the latest version of Fury with `furyctl`.
3. Install Fury distribution.
4. Explore some features of the distribution.
5. Teardown the environment.

> ☁️ If you prefer trying Fury in a cloud environment, check out the [Fury on EKS](../fury-on-eks) tutorial or the [Fury on GKE](../fury-on-gke) tutorial.

## Prerequisites

This tutorial assumes some basic familiarity with Kubernetes.

To follow this tutorial, you need:

- **Minikube** - follow the [installation guide](https://minikube.sigs.k8s.io/docs/start/).
- **Docker** - a [Docker image]([fury-getting-started]) containing `furyctl` and all the necessary tools is provided.

### Setup and initialize the environment

1. Open a terminal

2. Clone the [fury getting started repository](https://github.com/sighupio/fury-getting-started) containing all the example code used in this tutorial:

```bash
git clone https://github.com/sighupio/fury-getting-started/
cd fury-getting-started/fury-on-minikube
```

## Step 1 - Start minikube cluster

1. Start minikube cluster:

```bash
export REPO_DIR=$PWD 
export KUBECONFIG=$REPO_DIR/infrastructure/kubeconfig
cd $REPO_DIR/infrastructure
make setup
```

> ⚠️ This command will spin up by default a single-node Kubernetes v1.19.4 cluster, using VirtualBox driver: the node has 4 CPUs, 4096MB RAM and 20,000 MB Disk. Please have a look at [Makefile](infrastructure/Makefile) to change the default values.
> You can also pass custom parameters:
>
> ```bash
> make setup cpu=2 memory=2048
> ```

2. Run the `fury-getting-started` docker image:

```bash
docker run -ti --rm \
  -v $REPO_DIR:/demo \
  --env KUBECONFIG=/demo/infrastructure/kubeconfig \
  --net=host \
   registry.sighup.io/delivery/fury-getting-started
```

3. Test the connection to the Minikube cluster:

```bash
kubectl get nodes
```

Output:

```bash
NAME       STATUS   ROLES    AGE   VERSION
minikube   Ready    master   16m   v1.19.4
```

## Step 2 - Download fury modules

`furyctl` can do a lot more than deploying infrastructure. In this section, you use `furyctl` to download the monitoring, logging, and ingress modules of the Fury distribution.

### Inspect the Furyfile

`furyctl` needs a `Furyfile.yml` to know which modules to download.

For this tutorial, use the `Furyfile.yml` located at `/demo/Furyfile.yaml`:

```yaml
versions:
  monitoring: v1.12.2
  logging: v1.8.0
  ingress: v1.10.0

bases:
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
vendor
└── katalog
    ├── ingress
    ├── logging
    └── monitoring
```

## Step 3 - Installation

Each module is a Kustomize project. Kustomize allows to group together related Kubernetes resources and combine them to create more complex deployments. Moreover, it is flexible, and it enables a simple patching mechanism for additional customization.

To deploy the Fury distribution, use the following root `kustomization.yaml` located `/demo/manifests/kustomization.yaml`:

```yaml
resources:

# Ingress module
- ../vendor/katalog/ingress/forecastle
- ../vendor/katalog/ingress/nginx
- ../vendor/katalog/ingress/cert-manager

# Logging module
- ../vendor/katalog/logging/cerebro
- ../vendor/katalog/logging/curator
- ../vendor/katalog/logging/elasticsearch-single
- ../vendor/katalog/logging/fluentd
- ../vendor/katalog/logging/kibana

# Monitoring module
- ../vendor/katalog/monitoring/alertmanager-operated
- ../vendor/katalog/monitoring/goldpinger
- ../vendor/katalog/monitoring/grafana
- ../vendor/katalog/monitoring/kube-proxy-metrics
- ../vendor/katalog/monitoring/kube-state-metrics
- ../vendor/katalog/monitoring/eks-sm
- ../vendor/katalog/monitoring/metrics-server
- ../vendor/katalog/monitoring/node-exporter
- ../vendor/katalog/monitoring/prometheus-operated
- ../vendor/katalog/monitoring/prometheus-operator

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

- references the modules downloaded in the previous section
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

In Step 3, alongside the distribution, you have deployed Kubernetes ingresses to expose underlying services at the following HTTP routes:

- `forecastle.fury.info`
- `grafana.fury.info`
- `kibana.fury.info`

To access the ingresses more easily via the browser, configure your local DNS to resolve the ingresses to the external Minikube IP:

1. Get the address of the cluster IP:

```bash
minikube ip
<SOME_IP>
```

3. Add the following line to your local `/etc/hosts`:

```bash
<SOME_IP> forecastle.fury.info alertmanager.fury.info goldpinger.fury.info grafana.fury.info prometheus.fury.info kibana.fury.info

```

Now, you can reach the ingresses directly from your browser.

### Forecastle

[Forecastle](https://github.com/stakater/Forecastle) is an open-source control panel where you can access all exposed applications running on Kubernetes.

Navigate to <http://forecastle.fury.info> to see all the other ingresses deployed, grouped by namespace.

![Forecastle][forecastle-screenshot]

### Kibana

[Kibana](https://github.com/elastic/kibana) is an open-source analytics and visualization platform for Elasticsearch. Kibana lets you perform advanced data analysis and visualize data in various charts, tables, and maps. You can use it to search, view, and interact with data stored in Elasticsearch indices.

Navigate to <http://kibana.fury.info> or click the Kibana icon from Forecastle.

Click on `Explore on my own` to see the main dashboard.

#### Create a Kibana index

1. Open the menu on the right-top corner of the page.
2. Select `Stack Management` (it's on the very bottom of the menu).
3. Select `Index patterns` and click on `Create index pattern`.
4. Write `kubernetes-*` as index pattern and flag *Include system and hidden indices*
5. Click `Next step`.
6. Select `@timestamp` as time field.s
7. Click create the index.

#### Read the logs

Based on the index you created, you can read and query the logs.
Navigate through the menu again, and select `Discover`.

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

## Step 6 - Tear down

1. Stop the docker container:

```bash
# Execute this command inside the Docker container
exit
```

2. Delete the minikube cluster:

```bash
# Execute these commands from your local system, outside the Docker container
cd $REPO_DIR/infrastructure
make delete
```

## Conclusions

Congratulations, you made it! 🥳🥳

We hope you enjoyed this tour of Fury!

### Issues/Feedback

In case your ran into any problems feel free to open a issue here in GitHub.

### Where to go next?

More tutorials:

- [Fury on GKE][fury-on-gke]
- [Fury on EKS][fury-on-eks]

More about Fury:

- [Fury Documentation][fury-docs]

<!-- Links -->
[fury-getting-started-repository]: https://github.com/sighupio/fury-getting-started/
[fury-getting-started-dockerfile]: https://github.com/sighupio/fury-getting-started/blob/main/utils/docker/Dockerfile

[fury-on-minikube]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-minikube
[fury-on-eks]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-eks
[fury-on-gke]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-gke

[furyagent-repository]: https://github.com/sighupio/furyagent

[provisioner-bootstrap-aws-reference]: https://docs.kubernetesfury.com/docs/cli-reference/furyctl/provisioners/aws-bootstrap/

[tunnelblick]: https://tunnelblick.net/downloads.html
[openvpn-connect]: https://openvpn.net/vpn-client/
[github-ssh-key-setup]: https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account

[fury-docs]: https://docs.kubernetesfury.com
[fury-docs-modules]: https://docs.kubernetesfury.com/docs/overview/modules/

<!-- Images -->
[kibana-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/kibana.png?raw=true
[grafana-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/grafana.png?raw=true
[cerebro-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/cerebro.png?raw=true
[forecastle-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/forecastle.png?raw=true
