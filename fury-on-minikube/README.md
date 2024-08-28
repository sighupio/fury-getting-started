# Fury on minikube

This step-by-step tutorial helps you deploy a subset of the **Kubernetes Fury Distribution** on a local minikube cluster.

This tutorial covers the following steps:

1. Deploy a local minikube cluster.
2. Download the latest `furyctl` CLI.
3. Install Fury distribution using `furyctl` CLI.
4. Explore some features of the distribution.
5. Teardown the environment.

> ☁️ If you prefer trying Fury in a cloud environment, check out the [Fury on EKS][fury-on-eks] tutorial.

The goal of this tutorial is to introduce you to the main concepts of KFD and how to work with its tooling.

## Prerequisites

This tutorial assumes some basic familiarity with Kubernetes.

To follow this tutorial, you need:

- **minikube** - follow the [installation guide](https://minikube.sigs.k8s.io/docs/start/). This guide is based on minikube with the VirtualBox driver. You can also run the minikube cluster with other drivers.
- **kubectl** - to interact with the cluster.

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
    export KUBECONFIG=$REPO_DIR/kubeconfig
    minikube start --vm-driver=virtualbox --kubernetes-version v1.29.3 --memory=16384m --cpus=6
    ```

    > ⚠️ This command will spin up by default a single-node Kubernetes v1.29.3 cluster, using VirtualBox driver, with 6 CPUs, 16GB RAM and 20 GB Disk.

2. Test the connection to the minikube cluster:

    ```bash
    kubectl get nodes
    ```

    Output:

    ```bash
    NAME       STATUS   ROLES           AGE   VERSION
    minikube   Ready    control-plane   9s    v1.29.3
    ```

## Step 3 - Install furyctl

Install `furyctl` binary: https://github.com/sighupio/furyctl#installation version `>=0.29.0`.

## Step 3 - Installation

In this directory, an example `furyctl.yaml` file is present.

`furyctl` will use the provider `KFDDistribution` that will install only the Distribution on top of an existing cluster.

```yaml
apiVersion: kfd.sighup.io/v1alpha2
kind: KFDDistribution
metadata:
  name: fury-local
spec:
  distributionVersion: v1.29.3
  distribution:
    kubeconfig: "{env://KUBECONFIG}"
    modules:
      networking:
        type: none
      ingress:
        baseDomain: internal.demo.example.dev
        nginx:
          type: single
          tls:
            provider: certManager
        certManager:
          clusterIssuer:
            name: letsencrypt-fury
            email: example@sighup.io
            type: http01
      logging:
        type: loki
      monitoring:
        type: prometheus
      policy:
        type: none
      dr:
        type: none
        velero: {}
      auth:
        provider:
          type: none
    customPatches:
      patchesStrategicMerge:
        - |
          $patch: delete
          apiVersion: logging-extensions.banzaicloud.io/v1alpha1
          kind: HostTailer
          metadata:
            name: systemd-common
            namespace: logging
        - |
          $patch: delete
          apiVersion: logging-extensions.banzaicloud.io/v1alpha1
          kind: HostTailer
          metadata:
            name: systemd-etcd
            namespace: logging
        - |
          $patch: delete
          apiVersion: apps/v1
          kind: DaemonSet
          metadata:
            name: x509-certificate-exporter-control-plane
            namespace: monitoring
```

In this example, we are installing the distribution with the following options:

- No CNI installation, minikube comes with a CNI by default
- A single battery of nginx
- Loki as storage for the logs
- No gatekeeper installation
- No velero and DR installation
- No Auth on the ingresses
- Disabled some logging extensions due to minikube incompatibilities
- Disabled master certificate-exporter, due to minikube incompatibilities

Execute the installation with furyctl:

```bash
furyctl apply --outdir $PWD
```

> ⏱ The process will take some minutes to complete, you can follow the progress in detail by running the following command:
>
> ```bash
> tail -f .furyctl/furyctl.<timestamp>-<random-id>.log | jq
> ```
>
> `--outdir` flag is used to define in which directory to create the hidden `.furyctl` folder that contains all the required files to install the cluster.
> If not provided, a `.furyctl` folder will be created in the user home.

The output should be similar to the following:

```bash
INFO Downloading distribution...
INFO Validating configuration file...
INFO Downloading dependencies...
INFO Validating dependencies...
INFO Running preflight checks
INFO Checking that the cluster is reachable...
INFO Cannot find state in cluster, skipping...
INFO Running preupgrade phase...
INFO Preupgrade phase completed successfully
INFO Installing Kubernetes Fury Distribution...
INFO Checking that the cluster is reachable...
INFO Checking storage classes...
INFO Checking if all nodes are ready...
INFO Applying manifests...
INFO Kubernetes Fury Distribution installed successfully
INFO Applying plugins...
INFO Skipping plugins phase as spec.plugins is not defined
INFO Saving furyctl configuration file in the cluster...
INFO Saving distribution configuration file in the cluster...
```

🚀 The (subset of the) distribution is finally deployed! In this section you will explore some of its features.

## Step 4 - Explore the distribution

### Setup local DNS

In Step 3, alongside the distribution, you have deployed Kubernetes ingresses to expose underlying services at the following HTTP routes:

- `directory.internal.demo.example.dev`
- `grafana.internal.demo.example.dev`
- `prometheus.internal.demo.example.dev`

To access the ingresses more easily via the browser, configure your local DNS to resolve the ingresses to the external minikube IP:

> ℹ️ the following commands should be executed in another terminal of your host. Not inside the fury-getting-started container.

1. Get the address of the cluster IP:

    ```bash
    minikube ip
    <SOME_IP>
    ```

2. Add the following line to your local `/etc/hosts`:

    ```bash
    <SOME_IP> directory.internal.demo.example.dev grafana.internal.demo.example.dev prometheus.internal.demo.example.dev
    ```

Now, you can reach the ingresses directly from your browser.

### Forecastle

[Forecastle](https://github.com/stakater/Forecastle) is an open-source control panel where you can access all exposed applications running on Kubernetes.

Navigate to https://directory.fury.info:31443 to see all the other ingresses deployed, grouped by namespace.

![Forecastle][forecastle-screenshot]

### Grafana

[Grafana](https://github.com/grafana/grafana) is an open-source platform for monitoring and observability. Grafana allows you to query, visualize, alert, and understand your metrics.

Navigate to https://grafana.internal.demo.example.dev:31443 or click the Grafana icon from Forecastle (remember to append the port 31443 to the url).

#### Discover the logs

Navigate to grafana, and:

1. Click on explore
2. Select Loki datasource
3. Run your query!

This is what you should see:

![Grafana Logs][grafana-screenshot-logs]

#### Discover dashboards

Fury provides some pre-configured dashboards to visualize the state of the cluster. Examine an example dashboard:

1. Click on the search icon on the left sidebar.
2. Write `pods` and click enter.
3. Select the `Kubernetes/Pods` dashboard.

![Grafana][grafana-screenshot]

Make sure to select a namespace that has pods running and then select one of those pods.

Take a look around and test the other dashboards available.

## Step 6 - Tear down

1. Delete the minikube cluster:

    ```bash
    minikube delete
    ```

## Conclusions

Congratulations, you made it! 🥳🥳

We hope you enjoyed this tour of Fury!

### Issues/Feedback

In case you ran into any problems feel free to [open an issue in GitHub](https://github.com/sighupio/fury-getting-started/issues/new).

### Where to go next?

More tutorials:

- [Fury on EKS][fury-on-eks]
- [Fury on VMs][fury-on-vms]

More about Fury:

- [Fury Documentation][fury-docs]

<!-- Links -->
[fury-on-eks]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-eks
[fury-on-vms]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-vms

[fury-docs]: https://docs.kubernetesfury.com

<!-- Images -->
[grafana-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/grafana.png?raw=true
[grafana-screenshot-logs]: https://github.com/sighupio/fury-getting-started/blob/media/grafana-logs.png?raw=true
[forecastle-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/forecastle_minikube.png?raw=true
