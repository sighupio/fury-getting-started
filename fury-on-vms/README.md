# Fury on VMs

This step-by-step tutorial helps you deploy a full Kubernetes Fury Cluster on VMS.

> ☁️ If you prefer trying Fury in a cloud environment, check out the [Fury on EKS](../fury-on-eks) tutorial.

The goal of this tutorial is to introduce you to the main concepts of KFD and how to work with its tooling.

## Prerequisites

This tutorial assumes some basic familiarity with Kubernetes.

To follow this tutorial, you need:

- **kubectl** - 1.26.x to interact with the cluster.
- **furyagent** - to provision initial cluster PKIs, install the latest version following the instructions [here](https://github.com/sighupio/furyagent)
- **ansible** - used by furyctl to execute the roles from KFD installers
- VMs OS: Rocky linux 8, Debian 12, or Ubuntu 20
- Valid FQDN for all the VMs, with a valid domain: for example, each VMs should have a corresponding DNS like worker1.example.tld, worker2.example.tld, master1.worker.tld, etc.
- Two VMs for the LoadBalancer Nodes (at least 1vcpu 1GB ram each)
- An additional IP that will be used by keepalived to expose the two loadbalancers in HA, and a DNS record pointed to this IP for the control-plane address.
- Three VMs for the master nodes (at least 2vcpu and 4GB ram each)
- Three VMs for the worker nodes (at least 4vcpu and 8GB ram each)
- `root` ssh access on the VMs

## Step 0 - Setup and initialize the environment

1. Open a terminal

2. Clone the [fury getting started repository](https://github.com/sighupio/fury-getting-started) containing all the example code used in this tutorial:

```bash
git clone https://github.com/sighupio/fury-getting-started/
cd fury-getting-started/fury-on-vms
```

## Step 1 - Initialize the PKIs

First of all we need to initialize the CA certificates used by kubernetes and etcd. To do that, you need to run the following command:

```bash
furyagent init master
furyagent init etcd
```

> The `furyagent` command needs the file `furyagent.yaml` as a configuration, this file is already present in the getting started directory.

After the initalization of the PKIs, you should have a `pki` folder with the following contents:

```text
pki
├── etcd
│  ├── ca.crt
│  └── ca.key
└── master
   ├── ca.crt
   ├── ca.key
   ├── front-proxy-ca.crt
   ├── front-proxy-ca.key
   ├── sa.key
   └── sa.pub
```
## Step 2 - Install furyctl

Install `furyctl` binary: https://github.com/sighupio/furyctl#installation version 0.26.2.

## Step 3 - Decide the strategy for the SSL certificates

To expose the KFD ingresses, we are using the https protocol. There are two approaches to achieve this:

1) Provide a self-signed certificate
2) Use cert-manager to generate the certificates


### Self-signed certificate

If you are using the first approach, you need to have at hand the files tls.key tls.crt and ca.crt.
If you want to generate these files using openssl, you can run the following commands:

```bash
openssl genrsa -out ca-key.pem 2048
openssl req -x509 -new -days 365 -nodes -key ca-key.pem -out ca.crt -subj "/CN=kube-ca"
openssl genrsa -out tls.key 2048
openssl req -new -key tls.key -out csr.pem -subj "/CN=kube-ca" -config req-dns.cnf 
openssl x509 -req -in csr.pem -CA ca.crt -CAkey ca-key.pem -CAcreateserial -out tls.crt -days 365 -extensions v3_req -extfile req-dns.cnf
```

The file `req-dns.cnf` is already present the tutorial directory, with the following content:

```text
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = fury.example.tld
DNS.2 = *.fury.example.tld
```

Change it accordingly to your environment

### Cert-manager

If using cert-manager, you can use the http01 challenge to get certificates from let's encrypt, only if your load-balancer is reachable from the internet, otherwise, we suggest to use a dns01 solvers that can use an authoritative DNS zone to emit certificates. We will use this approach on the tutorial.

## Step 4 - Write the `furyctl.yaml` configuration file

The next step is to write the configuration file used by `furyctl`, in the tutorial directory is present a pre-compiled file that you can use as a starting point.

We will explain in this step, what the important fields are for.

### `.spec.kubernetes`

#### PKIs and access

```yaml
---
spec:
  kubernetes:
    pkiFolder: ./pki
    ssh:
      username: root
      keyPath: ./ssh-key
```

This first piece of configuration, defines where to find the PKIs (create on the step 1), and the ssh connection detail for the `root` user.
On `keyPath`, it's possible to use a relative path or an absolute path

#### common DNS zone and networking

```yaml
---
spec:
  kubernetes:
    dnsZone: example.tld
    controlPlaneAddress: control-plane.example.tld:6443
    podCidr: 172.16.128.0/17
    svcCidr: 172.16.0.0/17
```
Next we need to define the dnsZone used by all the nodes, and the control-plane address. Also we need to define the podCidr and svcCidr used in the cluster, and these CIDRs must not collide with the IPs of the nodes.

#### Load Balancers configuration

```yaml
spec:
  kubernetes:
    loadBalancers:
      enabled: true
      hosts:
        - name: haproxy1
          ip: 192.168.1.177
        - name: haproxy2
          ip: 192.168.1.178
      keepalived:
        enabled: true
        interface: enp0s8
        ip: 192.168.1.179/32
        virtualRouterId: "201"
        passphrase: "b16cf069"
      stats:
        username: admin
        password: password
      additionalConfig: "{file://./haproxy-additional.cfg}"
```

Next we need to define the loadBalancer nodes, each node will have a name and an ip address, additionally we are also enabling keepalived on an additional IP address, in this example `192.168.1.179`. **Important** check which is the main interface that will be used for the keepalive IP, in this example `enp0s8`.

We need also to give the HAproxy stat page an username and a password, and we can also add an additional config to the load balancers. In the example file we are also balancing the ingress battery using the same load balancers as the control plane address.

#### Kubernetes Master and Worker nodes

```yaml
spec:
  kubernetes:
    masters:
      hosts:
        - name: master1
          ip: 192.168.1.181
        - name: master2
          ip: 192.168.1.182
        - name: master3
          ip: 192.168.1.183
    nodes:
      - name: worker
        hosts:
          - name: worker1
            ip: 192.168.1.184
          - name: worker2
            ip: 192.168.1.185
          - name: worker3
            ip: 192.168.1.186
```

Next we need to define the masters node and the worker nodes. The fqdn that will be used for each node will be the concatenation of the name and the `.spec.kubernetes.dnsZone` field.

For example, master1 will become: master1.example.tld.

### `.spec.distribution`

#### Networking core module

```yaml
spec:
  distribution:
    modules:
      networking:
        type: calico
```

In this piece of configuration, we choosing to install calico as CNI in our cluster from the `fury-kubernetes-networking` core module.

#### Ingress core module

```yaml
spec:
  distribution:
    modules:
      ingress:
        baseDomain: fury.example.tld
        nginx:
          type: single
          tls:
            provider: certManager
        certManager:
          clusterIssuer:
            name: letsencrypt-fury
            email: example@sighup.io
            solvers:
              - dns01:
                  route53:
                    region: eu-west-1
                    accessKeyID: AKIAEXAMPLE
                    secretAccessKeySecretRef:
                      name: letsencrypt-production-route53-key
                      key: secret-access-key
```

In this section, on the configuration of the `fury-kubernetes-ingress` core module, we are selecting to install a single battery of nginx ingress controller and configuring cert-manager as the provider to emit SSL certificates for our ingresses.

To correctly configure the cert-manager clusterIssuer we need to put a valid configuration for the dns01 solver. The secret `letsencrypt-production-route53-key` will be installed using the plugins feature.

> If instead you want to use a self-signed certificate (or a valid one from a file), you need to configure the ingress module like the following:
> ```yaml
>spec:
>  distribution:
>    modules:
>      ingress:
>        baseDomain: fury.example.tld
>        nginx:
>          type: single
>          tls:
>            provider: secret
>            secret:
>              cert: "{file://./tls.crt}"
>              key: "{file://./tls.key}"
>              ca: "{file://./ca.crt}"
>        certManager:
>          clusterIssuer:
>            name: letsencrypt-fury
>            email: example@sighup.io
>            type: http01
> ```

#### Logging core module

```yaml
spec:
  distribution:
    modules:
      logging:
        type: loki
        minio:
          storageSize: "20Gi"
```

This section configures the `fury-kubernetes-logging` module. In this example we are installing loki as log storage, and configuring the logging operator with all the Flows and Outputs to send logs to loki stack.

The minio configuration is the S3 bucket used by loki to store logs, the storageSize selected defines the size for each minio disk, in total 6 disk splitted in 2 per 3 minio replicas.

#### Policy (OPA) core module

```yaml
spec:
  distribution:
    modules:
      policy:
        type: none
```

For simplicity, we are not installing gatekeeper in the cluster, from the `fury-kubernetes-opa` module.

#### DR core module

```yaml
spec:
  distribution:
    modules:
      dr:
        type: on-premises
        velero: {}
```

We are also configuring velero for the cluster backups from the `fury-kubernetes-dr` module. Velero will be deployed with a minio instance used to store all the backups.

```yaml
spec:
  distribution:
    modules:
      auth:
        provider:
          type: none 
```

This section configures the authentication for the ingresses and also the authentication via oidc on the APIServer, for simplicity we are disabling the authentication on the ingresses and not configuring the oidc authentication for the APIserver.

### `.spec.plugins`

```yaml
spec:
  plugins:
    kustomize: 
      - name: cert-manager-secret
        folder: ./cert-manager-secret/
      - name: storage
        folder: https://github.com/rancher/local-path-provisioner/deploy?ref=v0.0.24
```

This section configures additional plugins to be installed in the cluster. There can be two types of plugin, `helm` and `kustomize`, in this example we are installing two kustomize projects.

The first one, under the `cert-manager-secret` folder, installs the secret used by cert-manager to interact with the route53 zone for the dns01 challenge. Change the example values in the `./cert-manager-secret` folder with the correct credentials to interact with your route53 zone. 
The second one, storage, installs the local-path-provisioner that provides a simple dynamic storage for the cluster (not production grade).


## Step 5 - Launch the installation with `furyctl`

Now that everything is configured you can proceed with the installation using the `furyctl` CLI. 

Simply execute:

```bash
furyctl create cluster --outdir $PWD
```

> ⏱ The process will take some minutes to complete, you can follow the progress in detail by running the following command:
>
> ```bash
> tail -f .furyctl/furyctl.log | jq
> ```
> `--outdir` flag is used to define in which directory to create the hidden `.furyctl` folder that contains all the required files to install the cluster. 
> If not provided, a `.furyctl` folder will be created in the user home.

The output should be similar to the following:

```bash
INFO Downloading distribution...                  
INFO Validating configuration file...             
INFO Downloading dependencies...                  
INFO Validating dependencies...                   
INFO Creating Kubernetes Fury cluster...          
INFO Checking that the hosts are reachable...     
INFO Running ansible playbook...                  
INFO Kubernetes cluster created successfully      
INFO Installing Kubernetes Fury Distribution...   
INFO Checking that the cluster is reachable...    
INFO Checking storage classes...                  
WARN No storage classes found in the cluster. logging module (if enabled), dr module (if enabled) and prometheus-operated package installation will be skipped. You need to install a StorageClass and re-run furyctl to install the missing components. 
INFO Applying manifests...                        
INFO Kubernetes Fury Distribution installed successfully 
INFO Applying plugins...                          
INFO Plugins installed successfully               
INFO Saving furyctl configuration file in the cluster... 
INFO Saving distribution configuration file in the cluster...
```

🚀 Success! The first deployment step is complete. Run furyctl again to install all the components that needs a working storageClass now, since we installed one using plugins function.

```bash
furyctl create cluster --outdir $PWD --skip-deps-download
```

> To speed up the following executions, you can use `--skip-deps-download`. This works only if the `.furyctl` folder has been already initialized.

```bash
INFO Downloading distribution...                  
INFO Validating configuration file...             
INFO Downloading dependencies...                  
INFO Validating dependencies...                   
INFO Creating Kubernetes Fury cluster...          
INFO Checking that the hosts are reachable...     
INFO Running ansible playbook...                  
INFO Kubernetes cluster created successfully      
INFO Installing Kubernetes Fury Distribution...   
INFO Checking that the cluster is reachable...    
INFO Checking storage classes...                  
INFO Applying manifests...                        
INFO Kubernetes Fury Distribution installed successfully 
INFO Applying plugins...                          
INFO Plugins installed successfully               
INFO Saving furyctl configuration file in the cluster... 
INFO Saving distribution configuration file in the cluster...
```

To interact with the cluster a `kubeconfig` has been created on the folder, make it usable with `kubectl` with:

```bash
export KUBECONFIG=$PWD/kubeconfig
```

## Step 6 - Explore the distribution

### Forecastle

[Forecastle](https://github.com/stakater/Forecastle) is an open-source control panel where you can access all exposed applications running on Kubernetes.

Navigate to <https://directory.fury.example.tld> to see all the other ingresses deployed, grouped by namespace.

![Forecastle][forecastle-screenshot]

### Grafana

[Grafana](https://github.com/grafana/grafana) is an open-source platform for monitoring and observability. Grafana allows you to query, visualize, alert, and understand your metrics.

Navigate to <https://grafana.fury.example.tld> or click the Grafana icon from Forecastle.


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

This is what you should see:

![Grafana][grafana-screenshot]

## Conclusions

Congratulations, you made it! 🥳🥳

We hope you enjoyed this tour of Fury!

### Issues/Feedback

In case you ran into any problems feel free to [open an issue in GitHub](https://github.com/sighupio/fury-getting-started/issues/new).

### Where to go next?

More tutorials:

- [Fury on EKS][fury-on-eks]
- [Fury on Minikube][fury-on-minikube]

More about Fury:

- [Fury Documentation][fury-docs]

<!-- Links -->
[fury-getting-started-repository]: https://github.com/sighupio/fury-getting-started/
[fury-getting-started-dockerfile]: https://github.com/sighupio/fury-getting-started/blob/main/utils/docker/Dockerfile

[fury-on-minikube]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-minikube
[fury-on-eks]: https://github.com/sighupio/fury-getting-started/tree/main/fury-on-eks

[furyagent-repository]: https://github.com/sighupio/furyagent

[fury-docs]: https://docs.kubernetesfury.com
[fury-docs-modules]: https://docs.kubernetesfury.com/docs/overview/modules/

<!-- Images -->
[grafana-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/grafana.png?raw=true
[grafana-screenshot-logs]: https://github.com/sighupio/fury-getting-started/blob/media/grafana-logs.png?raw=true
[forecastle-screenshot]: https://github.com/sighupio/fury-getting-started/blob/media/forecastle_minikube.png?raw=true
