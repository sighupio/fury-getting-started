#!/bin/bash

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform

# Ansible
sudo add-apt-repository -y ppa:ansible/ansible
sudo apt update && sudo apt install -y ansible

# Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
&& sudo mv ./kubectl /usr/local/bin/kubectl \
&& sudo chmod 0755 /usr/local/bin/kubectl

# Furyctl
wget -q "https://github.com/sighupio/furyctl/releases/download/v0.9.0/furyctl-$(uname -s)-amd64" -O /tmp/furyctl \
&& chmod +x /tmp/furyctl \
&& sudo mv /tmp/furyctl /usr/local/bin/furyctl

# Kustomize
wget https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.5.3/kustomize_v3.5.3_linux_amd64.tar.gz \
&& tar -zxvf ./kustomize_v3.5.3_linux_amd64.tar.gz \
&& chmod u+x ./kustomize \
&& sudo mv ./kustomize /usr/local/bin/kustomize \
&& rm ./kustomize_v3.5.3_linux_amd64.tar.gz
